import atexit
import csv
import io
import json
import os
import re
import select
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import termios
import tty
from pathlib import Path

# Configuration
DB_KEYWORDS = ["postgres", "mysql", "mariadb", "sqlite"]
DB_PORTS = ["5432", "3306"]
MAX_COL_WIDTH = 35

# ANSI Colors & Styling
CYAN = "\033[96m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
MAGENTA = "\033[95m"
RED = "\033[91m"
DIM = "\033[2m"
BOLD = "\033[1m"
REVERSE = "\033[7m"
RESET = "\033[0m"


# -------------------------------------------------------------------
#  TERMINAL DISPLAY & CURSOR MANAGEMENT
# -------------------------------------------------------------------

def strip_ansi(text):
    """Strips ANSI escape codes to calculate true visible string length."""
    return re.sub(r'\x1b\[[0-9;]*m', '', str(text))


def visible_len(text):
    return len(strip_ansi(text))


def enter_alt_screen():
    """Switches to alternate terminal buffer and hides cursor."""
    sys.stdout.write("\033[?1049h\033[?25l")
    sys.stdout.flush()


def exit_cleanup():
    """Restores main terminal buffer and unhides cursor cleanly on exit."""
    sys.stdout.write("\033[?25h\033[?1049l")
    sys.stdout.flush()


# Automatically handle screen buffer & cursor restoration on exit
atexit.register(exit_cleanup)
enter_alt_screen()


def draw_frame(lines):
    """
    Zero-flicker in-place frame renderer.
    Flattens embedded newlines and clears every line to guarantee zero ghost text.
    """
    flat_lines = []
    for item in lines:
        flat_lines.extend(str(item).split("\n"))

    # \033[K clears from cursor to end of row
    formatted = [line + "\033[K" for line in flat_lines]
    
    # \033[H moves to (1,1). \033[J clears screen below output
    output = "\033[H" + "\n".join(formatted) + "\n\033[J"
    sys.stdout.write(output)
    sys.stdout.flush()


def get_key():
    """Captures a single keypress cleanly with non-blocking escape sequence parsing."""
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        ch = sys.stdin.read(1)

        if ch == '\x1b':
            r, _, _ = select.select([sys.stdin], [], [], 0.05)
            if r:
                ch2 = sys.stdin.read(1)
                if ch2 == '[':
                    r2, _, _ = select.select([sys.stdin], [], [], 0.05)
                    if r2:
                        ch3 = sys.stdin.read(1)
                        if ch3 == 'A': return 'k'  # Up Arrow
                        if ch3 == 'B': return 'j'  # Down Arrow
                        if ch3 == 'C': return 'l'  # Right Arrow
                        if ch3 == 'D': return 'h'  # Left Arrow
            return 'q'  # ESC key

        if ch in ('\r', '\n'):
            return 'ENTER'
        if ch == ' ':
            return 'SPACE'
        if ch == '\x04':  # Ctrl+D
            return 'CTRL_D'
        if ch == '\x15':  # Ctrl+U
            return 'CTRL_U'
        return ch
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)


def get_terminal_size():
    try:
        sz = shutil.get_terminal_size()
        return sz.columns, sz.lines
    except Exception:
        return 100, 24


def launch_nvim_editor(data_dict):
    """Opens Neovim with row data formatted as JSON."""
    edit_dict = {}
    json_fields = set()

    for key, val in data_dict.items():
        if isinstance(val, str) and ((val.startswith('{') and val.endswith('}')) or (val.startswith('[') and val.endswith(']'))):
            try:
                edit_dict[key] = json.loads(val)
                json_fields.add(key)
                continue
            except json.JSONDecodeError:
                pass
        edit_dict[key] = val

    with tempfile.NamedTemporaryFile(mode='w+', suffix='.json', delete=False) as tf:
        json.dump(edit_dict, tf, indent=2, ensure_ascii=False)
        temp_path = tf.name

    editor = os.environ.get('EDITOR')
    if not editor:
        editor = 'nvim' if shutil.which('nvim') else ('vim' if shutil.which('vim') else 'nano')

    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)

    try:
        sys.stdout.write("\033[?25h\033[?1049l")
        sys.stdout.flush()
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        subprocess.call([editor, temp_path])
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        termios.tcflush(fd, termios.TCIFLUSH)
        enter_alt_screen()

    try:
        with open(temp_path, 'r', encoding='utf-8') as f:
            updated_dict = json.load(f)
        os.remove(temp_path)
    except Exception as e:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        print(f"\n{RED}Error reading edited JSON or syntax error: {e}{RESET}")
        return None

    final_dict = {}
    for k, v in updated_dict.items():
        if k in json_fields and isinstance(v, (dict, list)):
            final_dict[k] = json.dumps(v)
        else:
            final_dict[k] = v

    return final_dict


# -------------------------------------------------------------------
#  GENERIC VIM + NUMBER MENU SELECTOR
# -------------------------------------------------------------------

def select_menu_item(title, items, display_key=None, subtext=None):
    if not items:
        return None

    cursor_idx = 0

    while True:
        term_width, _ = get_terminal_size()
        card_width = min(term_width - 2, 98)
        lines = []

        lines.append(f"{CYAN}{'=' * card_width}{RESET}")
        title_centered = title.center(card_width)
        lines.append(f"{BOLD}{YELLOW}{title_centered}{RESET}")
        lines.append(f"{CYAN}{'=' * card_width}{RESET}")

        if subtext:
            lines.append(f" {DIM}{subtext}{RESET}")
            lines.append("")

        for idx, item in enumerate(items, start=1):
            label = item[display_key] if display_key and isinstance(item, dict) else str(item)
            is_selected = (idx - 1 == cursor_idx)

            num_tag = f"[{idx}] "
            max_label_width = card_width - 6
            truncated_label = label[:max_label_width]

            if is_selected:
                padded_line = f"  {num_tag}{truncated_label}".ljust(card_width)
                lines.append(f"{REVERSE}{BOLD}{padded_line}{RESET}")
            else:
                lines.append(f"  {BOLD}{num_tag}{RESET}{truncated_label}")

        lines.append("")
        lines.append(f"{CYAN}{'-' * card_width}{RESET}")
        lines.append(f" {BOLD}Vim Nav:{RESET} {YELLOW}j/k{RESET} Up/Down | "
                     f"{YELLOW}Enter{RESET} Select | "
                     f"{YELLOW}1-{min(9, len(items))}{RESET} Direct Pick | "
                     f"{YELLOW}q{RESET} Back")

        draw_frame(lines)
        key = get_key()

        if key in ('j', 'J'):
            cursor_idx = min(cursor_idx + 1, len(items) - 1)
        elif key in ('k', 'K'):
            cursor_idx = max(cursor_idx - 1, 0)
        elif key == 'ENTER':
            return items[cursor_idx]
        elif key in '123456789':
            num = int(key) - 1
            if 0 <= num < len(items):
                return items[num]
        elif key.lower() in ('q', 'b'):
            return None


# -------------------------------------------------------------------
#  CONTAINER ENVIRONMENT INSPECTION
# -------------------------------------------------------------------

def get_container_env_user(container, engine):
    try:
        cmd = ["docker", "inspect", container, "--format", "{{json .Config.Env}}"]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        env_vars = json.loads(res.stdout.strip()) if res.stdout else []

        target_key = "POSTGRES_USER=" if engine == "postgres" else "MYSQL_USER="
        for var in env_vars:
            if var.startswith(target_key):
                return var.split("=", 1)[1]
    except Exception:
        pass

    return "postgres" if engine == "postgres" else "root"


# -------------------------------------------------------------------
#  TERMINAL FORMATTING UTILITIES & COLUMN CALCULATOR
# -------------------------------------------------------------------

def compute_cell_visible_len(val, max_col_w=MAX_COL_WIDTH):
    if val is None or val == "":
        return 4
    s = str(val).replace("\n", " ").strip()
    if (s.startswith("{") and s.endswith("}")) or (s.startswith("[") and s.endswith("]")):
        s_preview = f"{s[:14]}...{s[-3:]}" if len(s) > 20 else s
        return len(s_preview)
    return min(len(s), max_col_w)


def compute_column_widths(headers, rows, max_col_w=MAX_COL_WIDTH):
    """Pre-calculates exact column widths across ALL rows on the current page."""
    widths = []
    for c_idx, h in enumerate(headers):
        w = len(str(h))
        for r in rows:
            if c_idx < len(r):
                w = max(w, compute_cell_visible_len(r[c_idx], max_col_w))
        widths.append(min(w, max_col_w))
    return widths


def get_fitted_columns(headers, rows, col_start_idx, term_width):
    """Selects columns that fit strictly inside term_width - 2."""
    if not headers or not rows:
        return col_start_idx, col_start_idx + 1, []

    all_col_widths = compute_column_widths(headers, rows)
    target_width = max(20, term_width - 2)

    used_width = 1  # leading '+'
    col_end_idx = col_start_idx

    while col_end_idx < len(headers):
        w = min(all_col_widths[col_end_idx], target_width - 3)
        needed = w + 3  # ' ' + col_w + ' |'
        if used_width + needed > target_width and col_end_idx > col_start_idx:
            break
        used_width += needed
        col_end_idx += 1

    fitted_widths = [min(all_col_widths[i], target_width - 3) for i in range(col_start_idx, col_end_idx)]
    return col_start_idx, col_end_idx, fitted_widths


def build_ascii_table_lines(headers, rows, col_widths, cursor_idx=0):
    """Renders ASCII table strictly using pre-fitted col_widths."""
    lines = []
    if not headers or not rows or not col_widths:
        lines.append(f"  {DIM}(No data found){RESET}")
        return lines

    def format_cell(val, col_w):
        if val is None or val == "":
            return f"{DIM}{'NULL':<{col_w}}{RESET}"

        s = str(val).replace("\n", " ").strip()

        if (s.startswith("{") and s.endswith("}")) or (s.startswith("[") and s.endswith("]")):
            s_preview = f"{s[:14]}...{s[-3:]}" if len(s) > 20 else s
            if len(s_preview) > col_w:
                s_preview = s_preview[:col_w - 3] + "..." if col_w > 3 else s_preview[:col_w]
            return f"{DIM}{s_preview:<{col_w}}{RESET}"

        if len(s) > col_w:
            s_trunc = s[:col_w - 3] + "..." if col_w > 3 else s[:col_w]
            return f"{CYAN}{s_trunc:<{col_w}}{RESET}"

        return f"{s:<{col_w}}"

    sep = "+" + "+".join("-" * (w + 2) for w in col_widths) + "+"
    lines.append(f"{DIM}{sep}{RESET}")

    hdr_cells = [f"{headers[i]:<{col_widths[i]}}" for i in range(len(headers))]
    header_str = "| " + " | ".join(f"{BOLD}{h}{RESET}" for h in hdr_cells) + " |"
    lines.append(header_str)
    lines.append(f"{DIM}{sep.replace('-', '=')}{RESET}")

    for r_idx, row in enumerate(rows):
        row_cells = []
        for c_idx in range(len(headers)):
            cell_val = row[c_idx] if c_idx < len(row) else None
            row_cells.append(format_cell(cell_val, col_widths[c_idx]))

        line = "| " + " | ".join(row_cells) + " |"

        if r_idx == cursor_idx:
            lines.append(f"{REVERSE}{BOLD}{line}{RESET}")
        else:
            lines.append(line)

    lines.append(f"{DIM}{sep}{RESET}")
    return lines


# -------------------------------------------------------------------
#  VIM-STYLE ROW DETAIL PAGER
# -------------------------------------------------------------------

def build_vertical_card_lines(headers, row, row_num):
    term_width, _ = get_terminal_size()
    card_width = min(term_width - 2, 98)
    lines = []

    lines.append(f"{CYAN}{'=' * card_width}{RESET}")
    title_str = f"ROW #{row_num} DETAIL VIEW".center(card_width)
    lines.append(f"{BOLD}{YELLOW}{title_str}{RESET}")
    lines.append(f"{CYAN}{'=' * card_width}{RESET}")

    max_hdr_len = max(len(str(h)) for h in headers) if headers else 15

    for header, val in zip(headers, row):
        hdr_str = f"{BOLD}{MAGENTA}{str(header):<{max_hdr_len}}{RESET}"

        if val is None or val == "":
            lines.append(f"  {hdr_str} : {DIM}NULL{RESET}")
            continue

        val_str = str(val).strip()

        if (val_str.startswith("{") and val_str.endswith("}")) or (val_str.startswith("[") and val_str.endswith("]")):
            try:
                parsed = json.loads(val_str)
                pretty_json = json.dumps(parsed, indent=2)
                lines.append(f"  {hdr_str} : {GREEN}(JSON/Array){RESET}")
                for line in pretty_json.split("\n"):
                    lines.append(f"    {DIM}{line}{RESET}")
                continue
            except json.JSONDecodeError:
                pass

        if val_str in ["t", "f", "true", "false"]:
            colored_val = f"{BLUE}{val_str}{RESET}"
        elif any(k in header.lower() for k in ["status", "state"]):
            colored_val = f"{YELLOW}{val_str}{RESET}"
        elif any(k in header.lower() for k in ["created", "updated", "date", "at"]):
            colored_val = f"{CYAN}{val_str}{RESET}"
        else:
            colored_val = val_str

        lines.append(f"  {hdr_str} : {colored_val}")

    lines.append(f"{CYAN}{'=' * card_width}{RESET}")
    return lines


def browse_row_detail(headers, row, row_num, update_fn=None):
    card_lines = build_vertical_card_lines(headers, row, row_num)
    line_offset = 0

    while True:
        term_width, term_height = get_terminal_size()
        viewport_height = max(5, term_height - 5)

        max_offset = max(0, len(card_lines) - viewport_height)
        line_offset = max(0, min(line_offset, max_offset))

        frame_lines = []
        pct = int(((line_offset + viewport_height) / len(card_lines)) * 100) if max_offset > 0 else 100
        pct = min(100, pct)
        frame_lines.append(f" {BOLD}{CYAN}Row #{row_num} Detail Pager{RESET} "
                           f"[{line_offset + 1}-{min(len(card_lines), line_offset + viewport_height)}/{len(card_lines)} lines ({pct}%)]")
        frame_lines.append(f"{DIM}{'-' * min(term_width - 2, 98)}{RESET}")

        frame_lines.extend(card_lines[line_offset : line_offset + viewport_height])

        frame_lines.append("")
        frame_lines.append(f" {BOLD}Vim Nav:{RESET} {YELLOW}j/k{RESET} Line Up/Down | "
                           f"{YELLOW}e{RESET} Edit (nvim) | "
                           f"{YELLOW}g/G{RESET} Top/Bottom | "
                           f"{YELLOW}q/Esc/Enter{RESET} Return")

        draw_frame(frame_lines)
        key = get_key()

        if key in ('j', 'J'):
            line_offset += 1
        elif key in ('k', 'K'):
            line_offset -= 1
        elif key in ('CTRL_D', 'SPACE'):
            line_offset += viewport_height // 2
        elif key == 'CTRL_U':
            line_offset -= viewport_height // 2
        elif key == 'g':
            line_offset = 0
        elif key == 'G':
            line_offset = max_offset
        elif key.lower() == 'e':
            orig_dict = dict(zip(headers, row))
            updated_dict = launch_nvim_editor(orig_dict)
            if updated_dict and update_fn:
                success = update_fn(headers, row, updated_dict)
                if success:
                    sys.stdout.write("\033[?25h")
                    sys.stdout.flush()
                    print(f"\n{GREEN}Success! Row updated in database.{RESET}")
                    print(f" {DIM}Press any key to return...{RESET}")
                    get_key()
                    sys.stdout.write("\033[?25l")
                    sys.stdout.flush()
                    break
        elif key.lower() in ('q', 'b', 'enter'):
            break


# -------------------------------------------------------------------
#  SQL UPDATE ENGINES
# -------------------------------------------------------------------

def format_sql_value(val):
    if val is None:
        return "NULL"
    if isinstance(val, bool):
        return "TRUE" if val else "FALSE"
    if isinstance(val, (int, float)):
        return str(val)
    s_val = str(val).replace("'", "''")
    return f"'{s_val}'"


def build_where_clause(headers, orig_row):
    if "id" in headers:
        id_idx = headers.index("id")
        id_val = orig_row[id_idx]
        if id_val is not None:
            return f'"id" = {format_sql_value(id_val)}'

    clauses = []
    for h, v in zip(headers, orig_row):
        if v is None:
            clauses.append(f'"{h}" IS NULL')
        else:
            clauses.append(f'"{h}" = {format_sql_value(v)}')
    return " AND ".join(clauses)


def update_sqlite_row(db_path, table_name, headers, orig_row, updated_dict):
    changed = {k: v for k, v in updated_dict.items() if dict(zip(headers, orig_row)).get(k) != v}
    if not changed:
        print(f"\n{YELLOW}No changes detected.{RESET}")
        return False

    set_clause = ", ".join([f'"{k}" = ?' for k in changed.keys()])
    where_sql = build_where_clause(headers, orig_row)

    sql = f'UPDATE "{table_name}" SET {set_clause} WHERE {where_sql}'
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute(sql, list(changed.values()))
        conn.commit()
        conn.close()
        return True
    except Exception as e:
        print(f"\n{RED}Database Update Error: {e}{RESET}")
        return False


def update_postgres_row(container, dbname, table_name, headers, orig_row, updated_dict):
    changed = {k: v for k, v in updated_dict.items() if dict(zip(headers, orig_row)).get(k) != v}
    if not changed:
        print(f"\n{YELLOW}No changes detected.{RESET}")
        return False

    user = get_container_env_user(container, "postgres")
    set_clause = ", ".join([f'"{k}" = {format_sql_value(v)}' for k, v in changed.items()])
    where_sql = build_where_clause(headers, orig_row)

    sql = f'UPDATE "{table_name}" SET {set_clause} WHERE {where_sql};'
    cmd = ["docker", "exec", "-i", container, "psql", "-U", user, "-d", dbname, "-c", sql]

    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        return True
    else:
        print(f"\n{RED}Postgres Update Error: {res.stderr.strip()}{RESET}")
        return False


def update_mysql_row(container, dbname, table_name, headers, orig_row, updated_dict):
    changed = {k: v for k, v in updated_dict.items() if dict(zip(headers, orig_row)).get(k) != v}
    if not changed:
        print(f"\n{YELLOW}No changes detected.{RESET}")
        return False

    user = get_container_env_user(container, "mysql")
    set_clause = ", ".join([f'`{k}` = {format_sql_value(v)}' for k, v in changed.items()])
    where_sql = build_where_clause(headers, orig_row).replace('"', '`')

    sql = f'UPDATE `{table_name}` SET {set_clause} WHERE {where_sql};'
    cmd = ["docker", "exec", "-i", container, "mysql", "-u", user, "-D", dbname, "-e", sql]

    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        return True
    else:
        print(f"\n{RED}MySQL Update Error: {res.stderr.strip()}{RESET}")
        return False


# -------------------------------------------------------------------
#  SQLITE ENGINE
# -------------------------------------------------------------------

def get_sqlite_tables(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    tables = [row[0] for row in cursor.fetchall()]
    conn.close()
    return sorted(tables)


def get_sqlite_row_count(db_path, table_name):
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute(f'SELECT COUNT(*) FROM "{table_name}"')
        count = cursor.fetchone()[0]
        conn.close()
        return count
    except Exception:
        return 0


def query_sqlite_page(db_path, table_name, limit, offset, filter_query=None):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    where_clause = ""
    params = []
    if filter_query:
        cursor.execute(f'PRAGMA table_info("{table_name}")')
        cols = [col[1] for col in cursor.fetchall()]
        conditions = [f'"{col}" LIKE ?' for col in cols]
        where_clause = "WHERE " + " OR ".join(conditions)
        params = [f"%{filter_query}%"] * len(cols)

    sql = f'SELECT * FROM "{table_name}" {where_clause} LIMIT {limit} OFFSET {offset}'
    cursor.execute(sql, params)
    rows = cursor.fetchall()
    headers = [description[0] for description in cursor.description] if cursor.description else []

    conn.close()
    return headers, rows


# -------------------------------------------------------------------
#  DOCKER ENGINE & DATABASE DISCOVERY
# -------------------------------------------------------------------

def run_docker_cmd(cmd):
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return res.stdout.strip()
    except subprocess.CalledProcessError:
        return None


def get_postgres_dbs(container):
    user = get_container_env_user(container, "postgres")
    cmd = [
        "docker", "exec", "-i", container,
        "psql", "-U", user, "-At", "-c",
        "SELECT datname FROM pg_database WHERE datistemplate = false;"
    ]
    output = run_docker_cmd(cmd)
    if not output:
        return [user]
    return [db.strip() for db in output.split("\n") if db.strip()]


def get_mysql_dbs(container):
    user = get_container_env_user(container, "mysql")
    query = (
        "SELECT schema_name FROM information_schema.schemata "
        "WHERE schema_name NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys');"
    )
    cmd = ["docker", "exec", "-i", container, "mysql", "-u", user, "-B", "-N", "-e", query]
    output = run_docker_cmd(cmd)
    if not output:
        return []
    return [db.strip() for db in output.split("\n") if db.strip()]


def prompt_select_database(container, engine):
    if engine == "postgres":
        dbs = get_postgres_dbs(container)
    elif engine == "mysql":
        dbs = get_mysql_dbs(container)
    else:
        return None

    if not dbs:
        return None

    db_items = [{"name": db, "label": db} for db in dbs]
    selected = select_menu_item(f"Databases in '{container}'", db_items, display_key="label")
    return selected["name"] if selected else None


def get_postgres_tables(container, dbname):
    user = get_container_env_user(container, "postgres")
    cmd = ["docker", "exec", "-i", container, "psql", "-U", user, "-d", dbname, "-At", "-c",
           "SELECT tablename FROM pg_tables WHERE schemaname='public';"]
    output = run_docker_cmd(cmd)
    return sorted([t for t in output.split("\n") if t]) if output else []


def query_postgres_page(container, dbname, table, limit, offset, filter_query=None):
    user = get_container_env_user(container, "postgres")
    where_sql = f"WHERE CAST(row_to_json(t) AS text) ILIKE '%{filter_query}%'" if filter_query else ""
    sql = f'COPY (SELECT * FROM "{table}" t {where_sql} LIMIT {limit} OFFSET {offset}) TO STDOUT WITH CSV HEADER;'
    cmd = ["docker", "exec", "-i", container, "psql", "-U", user, "-d", dbname, "-c", sql]
    output = run_docker_cmd(cmd)
    if not output:
        return [], []

    reader = csv.reader(io.StringIO(output))
    data = list(reader)
    if not data:
        return [], []
    return data[0], data[1:]


def get_mysql_tables(container, dbname):
    user = get_container_env_user(container, "mysql")
    cmd = ["docker", "exec", "-i", container, "mysql", "-u", user, "-D", dbname, "-B", "-N", "-e", "SHOW TABLES;"]
    output = run_docker_cmd(cmd)
    return sorted([t for t in output.split("\n") if t]) if output else []


def query_mysql_page(container, dbname, table, limit, offset, filter_query=None):
    user = get_container_env_user(container, "mysql")
    sql = f'SELECT * FROM `{table}` LIMIT {limit} OFFSET {offset};'
    cmd = ["docker", "exec", "-i", container, "mysql", "-u", user, "-D", dbname, "-B", "-e", sql]
    output = run_docker_cmd(cmd)
    if not output:
        return [], []

    reader = csv.reader(io.StringIO(output), delimiter="\t")
    data = list(reader)
    if not data:
        return [], []

    headers = data[0]
    rows = data[1:]

    if filter_query:
        rows = [r for r in rows if any(filter_query.lower() in str(cell).lower() for cell in r)]

    return headers, rows


# -------------------------------------------------------------------
#  VIM / LESS INTERACTIVE BROWSER CONTROLLER
# -------------------------------------------------------------------

def browse_table(query_fn, update_fn=None, total_rows=None):
    """Interactive table pagination dynamically adjusted to monitor height."""
    offset = 0
    col_offset = 0
    cursor_idx = 0
    filter_text = None

    while True:
        term_width, term_height = get_terminal_size()
        page_size = max(3, term_height - 7)

        headers, rows = query_fn(limit=page_size, offset=offset, filter_query=filter_text)

        if rows:
            cursor_idx = max(0, min(cursor_idx, len(rows) - 1))
        else:
            cursor_idx = 0

        if headers and rows:
            col_offset = max(0, min(col_offset, len(headers) - 1))
            c_start, c_end, fitted_widths = get_fitted_columns(headers, rows, col_offset, term_width)
            sliced_headers = headers[c_start:c_end]
            sliced_rows = [r[c_start:c_end] for r in rows]
            col_status = f"Cols {c_start + 1}-{c_end}/{len(headers)}"
        else:
            sliced_headers, sliced_rows, fitted_widths = headers, rows, []
            col_status = "Cols 0-0"

        frame_lines = []
        status = f"Rows {offset + 1}-{offset + len(rows)}"
        if total_rows:
            status += f" of {total_rows}"
        if filter_text:
            status += f" (Filter: '{filter_text}')"

        frame_lines.append(f" {BOLD}{CYAN}Data Browser{RESET} [{status}] [{col_status}]  "
                           f"{DIM}(Press 'q' to back, '/' to search){RESET}")

        table_lines = build_ascii_table_lines(sliced_headers, sliced_rows, fitted_widths, cursor_idx=cursor_idx)
        frame_lines.extend(table_lines)

        frame_lines.append(f" {BOLD}Vim Nav:{RESET} {YELLOW}j/k{RESET} Up/Down | "
                           f"{YELLOW}h/l{RESET} Left/Right | "
                           f"{YELLOW}Enter/v{RESET} Card | "
                           f"{YELLOW}e{RESET} Edit (nvim) | "
                           f"{YELLOW}/{RESET} Search | "
                           f"{YELLOW}q{RESET} Back")

        draw_frame(frame_lines)
        key = get_key()

        if key in ('j', 'J'):
            if rows and cursor_idx < len(rows) - 1:
                cursor_idx += 1
            elif rows and len(rows) == page_size:
                offset += page_size
                cursor_idx = 0
        elif key in ('k', 'K'):
            if cursor_idx > 0:
                cursor_idx -= 1
            elif offset >= page_size:
                offset -= page_size
                cursor_idx = page_size - 1
        elif key in ('l', 'L'):
            if headers and col_offset < len(headers) - 1:
                col_offset += 1
        elif key in ('h', 'H'):
            if col_offset > 0:
                col_offset -= 1
        elif key in ('CTRL_D', 'SPACE'):
            if rows and len(rows) == page_size:
                offset += page_size
                cursor_idx = 0
        elif key == 'CTRL_U':
            if offset >= page_size:
                offset -= page_size
                cursor_idx = 0
        elif key == 'ENTER' or key.lower() == 'v':
            if rows and 0 <= cursor_idx < len(rows):
                browse_row_detail(headers, rows[cursor_idx], offset + cursor_idx + 1, update_fn=update_fn)
        elif key.lower() == 'e':
            if rows and 0 <= cursor_idx < len(rows):
                orig_dict = dict(zip(headers, rows[cursor_idx]))
                updated_dict = launch_nvim_editor(orig_dict)
                if updated_dict and update_fn:
                    success = update_fn(headers, rows[cursor_idx], updated_dict)
                    if success:
                        sys.stdout.write("\033[?25h")
                        sys.stdout.flush()
                        print(f"\n{GREEN}Success! Row updated in database.{RESET}")
                        print(f" {DIM}Press any key to continue...{RESET}")
                        get_key()
                        sys.stdout.write("\033[?25l")
                        sys.stdout.flush()
        elif key == '/' or key.lower() == 's':
            sys.stdout.write("\033[?25h")
            sys.stdout.flush()
            filter_text = input(" Enter search filter (or Enter to cancel): ").strip()
            sys.stdout.write("\033[?25l")
            sys.stdout.flush()
            if not filter_text:
                filter_text = None
            offset = 0
            cursor_idx = 0
        elif key.lower() == 'c':
            filter_text = None
            offset = 0
            cursor_idx = 0
        elif key.lower() in ('q', 'b'):
            break


# -------------------------------------------------------------------
#  DISCOVERY & MAIN MENU
# -------------------------------------------------------------------

def find_sqlite_files():
    sqlite_dbs = []
    for path in Path.cwd().glob("*"):
        if path.is_file():
            try:
                with open(path, "rb") as f:
                    if f.read(16) == b"SQLite format 3\x00":
                        sqlite_dbs.append(path)
            except (PermissionError, OSError):
                continue
    return sorted(sqlite_dbs, key=lambda x: x.name.lower())


def find_docker_databases():
    containers = []
    try:
        cmd = ["docker", "ps", "--format", "{{json .}}"]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        for line in res.stdout.strip().split("\n"):
            if not line:
                continue
            data = json.loads(line)
            img = data.get("Image", "").lower()
            ports = data.get("Ports", "").lower()

            if any(k in img for k in DB_KEYWORDS) or any(p in ports for p in DB_PORTS):
                engine = "postgres" if "postgres" in img else ("mysql" if "mysql" in img or "mariadb" in img else "other")
                containers.append({
                    "id": data.get("ID"),
                    "name": data.get("Names"),
                    "image": data.get("Image"),
                    "engine": engine
                })
    except Exception:
        return None
    return containers


def main():
    while True:
        sqlite_dbs = find_sqlite_files()
        docker_dbs = find_docker_databases()

        main_items = []
        if sqlite_dbs:
            for db in sqlite_dbs:
                size_kb = db.stat().st_size / 1024
                main_items.append({
                    "type": "sqlite",
                    "target": db,
                    "label": f"SQLite: {db.name:<25} ({size_kb:.1f} KB)"
                })
        if docker_dbs:
            for db in docker_dbs:
                main_items.append({
                    "type": "docker",
                    "target": db,
                    "label": f"{db['engine'].upper():<8} (Container: {db['name']})"
                })

        if not main_items:
            sys.stdout.write("\033[?25h")
            sys.stdout.flush()
            print("\n No databases detected in current directory or running Docker containers.")
            break

        selected_db = select_menu_item(
            "Interactive Database Browser & Explorer",
            main_items,
            display_key="label",
            subtext=f"Scanning: {Path.cwd()}"
        )

        if not selected_db:
            break

        db_type = selected_db["type"]
        target = selected_db["target"]

        # -------------------------------------------------------------
        #  SQLITE FLOW
        # -------------------------------------------------------------
        if db_type == "sqlite":
            while True:
                tables = get_sqlite_tables(target)
                if not tables:
                    sys.stdout.write("\033[?25h")
                    sys.stdout.flush()
                    print(f" (Database '{target.name}' contains no tables)")
                    input(" Press Enter to return...")
                    sys.stdout.write("\033[?25l")
                    sys.stdout.flush()
                    break

                table_items = []
                for t in tables:
                    count = get_sqlite_row_count(target, t)
                    table_items.append({
                        "name": t,
                        "label": f"{t:<30} ({count} rows)"
                    })

                selected_table = select_menu_item(
                    f"Tables in SQLite: {target.name}",
                    table_items,
                    display_key="label"
                )

                if not selected_table:
                    break

                t_name = selected_table["name"]
                total = get_sqlite_row_count(target, t_name)

                def q_fn(limit, offset, filter_query=None):
                    return query_sqlite_page(target, t_name, limit, offset, filter_query)

                def u_fn(headers, orig_row, updated_dict):
                    return update_sqlite_row(target, t_name, headers, orig_row, updated_dict)

                browse_table(q_fn, update_fn=u_fn, total_rows=total)

        # -------------------------------------------------------------
        #  DOCKER FLOW (Postgres / MySQL)
        # -------------------------------------------------------------
        elif db_type == "docker":
            c_name = target["name"]
            engine = target["engine"]

            dbname = prompt_select_database(c_name, engine)
            if not dbname:
                continue

            while True:
                if engine == "postgres":
                    tables = get_postgres_tables(c_name, dbname)
                elif engine == "mysql":
                    tables = get_mysql_tables(c_name, dbname)
                else:
                    break

                if not tables:
                    sys.stdout.write("\033[?25h")
                    sys.stdout.flush()
                    print(f" (No public tables found in {engine.upper()} database '{dbname}')")
                    input(" Press Enter to return...")
                    sys.stdout.write("\033[?25l")
                    sys.stdout.flush()
                    break

                table_items = [{"name": t, "label": t} for t in tables]

                selected_table = select_menu_item(
                    f"Tables in {engine.upper()}: {dbname}",
                    table_items,
                    display_key="label"
                )

                if not selected_table:
                    break

                t_name = selected_table["name"]

                def q_fn(limit, offset, filter_query=None):
                    if engine == "postgres":
                        return query_postgres_page(c_name, dbname, t_name, limit, offset, filter_query)
                    else:
                        return query_mysql_page(c_name, dbname, t_name, limit, offset, filter_query)

                def u_fn(headers, orig_row, updated_dict):
                    if engine == "postgres":
                        return update_postgres_row(c_name, dbname, t_name, headers, orig_row, updated_dict)
                    else:
                        return update_mysql_row(c_name, dbname, t_name, headers, orig_row, updated_dict)

                browse_table(q_fn, update_fn=u_fn)


if __name__ == "__main__":
    main()
