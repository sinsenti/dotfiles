#!/usr/bin/env python3
"""Pick a Codex or Claude Code session and open its latest exchange in Neovim.

Session metadata is read from the local JSONL stores. The newest session matching
the pane's working directory is suggested first; if none match, the newest valid
session overall is suggested. Fzf previews only the selected session's latest
exchange, reading backward from the end of its log.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterator


@dataclass(frozen=True)
class Session:
    provider: str
    path: Path
    cwd: str
    modified_ns: int


def normalized(path: str | Path) -> str:
    return os.path.normcase(os.path.realpath(os.fspath(path)))


def codex_session_cwd(path: Path) -> str | None:
    try:
        with path.open("r", encoding="utf-8") as session:
            first_line = session.readline()
        record = json.loads(first_line)
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None

    if not isinstance(record, dict):
        return None
    payload = record.get("payload")
    cwd = payload.get("cwd") if record.get("type") == "session_meta" and isinstance(payload, dict) else None
    return cwd if isinstance(cwd, str) else None


def claude_session_cwd(path: Path) -> str | None:
    """Find the cwd in the first Claude transcript record that contains one."""
    try:
        with path.open("r", encoding="utf-8") as session:
            for line in session:
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if not isinstance(record, dict):
                    continue
                cwd = record.get("cwd")
                if isinstance(cwd, str) and cwd:
                    return cwd
    except (OSError, UnicodeError):
        return None
    return None


def collect_sessions(root: Path, provider: str, recursive: bool) -> list[Session]:
    files: list[tuple[int, Path]] = []
    try:
        if recursive:
            paths = root.rglob("*.jsonl")
        else:
            paths = (path for project in root.iterdir() if project.is_dir() for path in project.glob("*.jsonl"))
        for path in paths:
            try:
                if path.is_file():
                    files.append((path.stat().st_mtime_ns, path))
            except OSError:
                continue
    except OSError:
        return []

    sessions: list[Session] = []
    cwd_reader = codex_session_cwd if provider == "codex" else claude_session_cwd
    for modified_ns, path in sorted(files, reverse=True):
        try:
            cwd = cwd_reader(path)
            if cwd:
                sessions.append(Session(provider, path, cwd, modified_ns))
        except OSError:
            continue
    return sessions


def list_sessions(codex_home: Path, claude_home: Path) -> list[Session]:
    sessions = collect_sessions(codex_home / "sessions", "codex", recursive=True)
    sessions.extend(collect_sessions(claude_home / "projects", "claude", recursive=False))
    return sorted(sessions, key=lambda session: (session.modified_ns, str(session.path)), reverse=True)


def suggested_session(sessions: list[Session], cwd: str) -> Session | None:
    if not sessions:
        return None
    wanted_cwd = normalized(cwd)
    return next((session for session in sessions if normalized(session.cwd) == wanted_cwd), sessions[0])


def reverse_lines(path: Path, block_size: int = 1024 * 1024) -> Iterator[bytes]:
    """Yield newline-delimited file records from the end without loading the full log."""
    with path.open("rb") as file:
        position = file.seek(0, os.SEEK_END)
        remainder = b""
        while position:
            size = min(block_size, position)
            position -= size
            file.seek(position)
            parts = (file.read(size) + remainder).split(b"\n")
            remainder = parts[0]
            for line in reversed(parts[1:]):
                if line:
                    yield line
        if remainder:
            yield remainder


def render_content(content: Any, provider: str) -> str:
    if isinstance(content, str):
        return content.strip()
    if not isinstance(content, list):
        return ""

    text_types = {"input_text", "output_text"} if provider == "codex" else {"text"}
    image_types = {"input_image", "output_image", "image"}
    sections: list[str] = []
    for block in content:
        if not isinstance(block, dict):
            continue
        block_type = block.get("type")
        if not isinstance(block_type, str):
            continue
        if block_type in text_types:
            text = block.get("text")
            if isinstance(text, str) and text.strip():
                sections.append(text.strip())
        elif block_type in image_types:
            sections.append("_[Image attachment omitted from text transcript]_")

    return "\n\n".join(sections)


def message_from_record(record: Any, provider: str) -> tuple[str, dict[str, Any]] | None:
    if not isinstance(record, dict):
        return None

    if provider == "codex":
        if record.get("type") != "response_item":
            return None
        message = record.get("payload")
        if not isinstance(message, dict) or message.get("type") != "message":
            return None
        role = message.get("role")
    else:
        role = record.get("type")
        if not isinstance(role, str) or role not in {"user", "assistant"}:
            return None
        message = record.get("message")
        if not isinstance(message, dict):
            return None
        message_role = message.get("role")
        if message_role is not None and message_role != role:
            return None

    if not isinstance(role, str) or role not in {"user", "assistant"}:
        return None
    return role, message


def exchange_markdown(session: Session) -> str:
    latest_user: str | None = None
    assistant_reversed: list[str] = []

    for raw_line in reverse_lines(session.path):
        try:
            record = json.loads(raw_line.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue

        parsed = message_from_record(record, session.provider)
        if parsed is None:
            continue
        role, message = parsed
        body = render_content(message.get("content"), session.provider)
        if not body:
            continue

        if role == "user":
            latest_user = body
            break
        assistant_reversed.append(body)

    if latest_user is None:
        return ""

    assistant_name = "Claude Code" if session.provider == "claude" else "Codex"
    sections = [f"# User\n\n{latest_user}"]
    if assistant_reversed:
        assistant_body = "\n\n".join(reversed(assistant_reversed))
        sections.append(f"# {assistant_name}\n\n{assistant_body}")
    return "\n\n".join(sections) + "\n"


def short_path(path: str) -> str:
    try:
        return "~" + str(Path(path).relative_to(Path.home()))
    except ValueError:
        return path


def provider_name(provider: str) -> str:
    return "Claude Code" if provider == "claude" else "Codex"


def pick_session(sessions: list[Session], suggested: Session) -> Session | None:
    fzf = shutil.which("fzf")
    if not fzf:
        raise RuntimeError("fzf is required to choose an agent session")

    ordered = [suggested, *(session for session in sessions if session != suggested)]
    rows: list[str] = []
    by_key = {(session.provider, str(session.path)): session for session in ordered}
    for session in ordered:
        modified = dt.datetime.fromtimestamp(session.modified_ns / 1_000_000_000).strftime("%Y-%m-%d %H:%M")
        marker = "★ suggested" if session == suggested else ""
        label = f"{marker}\t{modified} | {provider_name(session.provider)} | {short_path(session.cwd)} | {session.path.stem}"
        rows.append(f"{session.provider}\t{session.path}\t{label}")

    script = Path(__file__).resolve()
    preview = f"{shlex.quote(sys.executable)} {shlex.quote(str(script))} --preview {{1}} {{2}}"
    command = [
        fzf,
        "--delimiter", "\t",
        "--with-nth", "3..",
        "--no-sort",
        "--layout=reverse",
        "--border",
        "--prompt=Agent session> ",
        "--header=★ suggested is newest match (or newest overall) | Enter: open | Esc: cancel",
        "--preview", preview,
        "--preview-window=right:60%:wrap",
    ]
    result = subprocess.run(command, input="\n".join(rows) + "\n", text=True, stdout=subprocess.PIPE, check=False)
    if result.returncode in {1, 130}:
        return None
    if result.returncode:
        raise RuntimeError(f"fzf exited with status {result.returncode}")
    if not result.stdout.strip():
        return None

    fields = result.stdout.rstrip("\n").split("\t", 2)
    if len(fields) < 2:
        return None
    return by_key.get((fields[0], fields[1]))


def open_in_editor(markdown: str) -> None:
    editor = shlex.split(os.environ.get("VISUAL") or os.environ.get("EDITOR") or "nvim")
    if not editor or not shutil.which(editor[0]):
        raise RuntimeError(f"Editor not found: {editor[0] if editor else 'nvim'}")

    fd, name = tempfile.mkstemp(prefix="agent-session-", suffix=".md")
    path = Path(name)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as transcript:
            transcript.write(markdown)
        result = subprocess.run([*editor, "--", str(path)], check=False)
        if result.returncode:
            raise RuntimeError(f"Editor exited with status {result.returncode}")
    except BaseException:
        path.unlink(missing_ok=True)
        raise


def main() -> int:
    if len(sys.argv) == 4 and sys.argv[1] == "--preview":
        provider, session_path = sys.argv[2], Path(sys.argv[3])
        if provider not in {"codex", "claude"}:
            print("Unknown session provider")
            return 0
        try:
            session = Session(provider, session_path, "", 0)
            markdown = exchange_markdown(session)
            print(markdown or "No visible user/assistant exchange in this session.", end="\n" if not markdown else "")
        except (OSError, UnicodeError) as error:
            print(f"Could not preview session: {error}")
        return 0
    if len(sys.argv) != 1:
        print(f"Usage: {Path(sys.argv[0]).name} [--preview PROVIDER SESSION.jsonl]", file=sys.stderr)
        return 2

    cwd = Path.cwd()
    codex_home = Path(os.environ.get("CODEX_HOME") or (Path.home() / ".codex")).expanduser()
    claude_home = Path(os.environ.get("CLAUDE_CONFIG_DIR") or (Path.home() / ".claude")).expanduser()
    sessions = list_sessions(codex_home, claude_home)
    suggested = suggested_session(sessions, str(cwd))
    if suggested is None:
        print("No Codex or Claude Code sessions found", file=sys.stderr)
        return 1

    try:
        selected = pick_session(sessions, suggested)
        if selected is None:
            return 0
        markdown = exchange_markdown(selected)
        if not markdown:
            print(f"No visible user/assistant exchange found in {selected.path.name}", file=sys.stderr)
            return 1
        open_in_editor(markdown)
    except (OSError, RuntimeError, UnicodeError) as error:
        print(f"Could not open agent exchange: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
