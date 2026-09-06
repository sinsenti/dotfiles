#!/usr/bin/env python3
import sys
import os
import re
import shutil
import subprocess
from pathlib import Path


def extract_files_from_markdown(text: str) -> list[tuple[str, str]]:
    """
    Parses input text to extract pairs of (file_path, content).
    Supports:
      1. Markdown headings with backticks/quotes (e.g. ### `src/timetrace/config.py`)
      2. '=== path/to/file.ext ===' header blocks (e.g. === ./copy.py ===)
      3. 'File <N>: path/to/file.ext' labels (with or without backticks)
      4. First-line comments inside code fences (# path/to/file.ext)
    """
    text = text.replace("\xa0", " ").replace("\u00a0", " ")

    extracted = []
    seen_paths = set()
    headers = []

    # Pattern 1: === ./path/to/file.ext ===
    for m in re.finditer(
        r"(?:^|\n)===\s*`?[./]*([a-zA-Z0-9_\-\/\.]+\.[a-zA-Z0-9]+)`?\s*===", text
    ):
        headers.append((m.start(), m.end(), m.group(1).strip()))

    # Pattern 2: File 1: path/to/file.ext
    for m in re.finditer(
        r"(?:^|\n)File\s*\d*:\s*`?[./]*([a-zA-Z0-9_\-\/\.]+\.[a-zA-Z0-9]+)`?",
        text,
        re.IGNORECASE,
    ):
        headers.append((m.start(), m.end(), m.group(1).strip()))

    # Pattern 3: Headings (e.g. ### `src/timetrace/config.py`)
    for m in re.finditer(
        r'(?:^|\n)#+\s+.*?(?:`|\'|"|\*\*|\b)([a-zA-Z0-9_\-\/\.]+\.[a-zA-Z0-9]+)(?:`|\'|"|\*\*|\b)',
        text,
    ):
        headers.append((m.start(), m.end(), m.group(1).strip()))

    headers.sort(key=lambda x: x[0])

    filtered_headers = []
    last_end = -1
    for start, end, filepath in headers:
        if start >= last_end:
            clean_path = os.path.normpath(filepath)
            filtered_headers.append((start, end, clean_path))
            last_end = end

    for i, (start, end, filepath) in enumerate(filtered_headers):
        next_start = (
            filtered_headers[i + 1][0] if i + 1 < len(filtered_headers) else len(text)
        )
        section_text = text[end:next_start]

        content = extract_code_from_section(section_text)

        if filepath not in seen_paths and content.strip():
            extracted.append((filepath, content.strip() + "\n"))
            seen_paths.add(filepath)

    # Pattern 4: Fallback for comment headers (# path/to/file.ext)
    comment_pattern = re.compile(
        r"```[a-zA-Z0-9_\-]*\n(?:\#|\/\/|--)\s*`?[./]*([a-zA-Z0-9_\-\/\.]+\.[a-zA-Z0-9]+)`?\n(.*?)```",
        re.DOTALL,
    )

    for match in comment_pattern.finditer(text):
        filepath = os.path.normpath(match.group(1).strip())
        content = match.group(2)
        if filepath not in seen_paths and content.strip():
            extracted.append((filepath, content.strip() + "\n"))
            seen_paths.add(filepath)

    return extracted


def extract_code_from_section(section_text: str) -> str:
    """Extracts raw code from a section chunk, handling fenced and unfenced code."""
    code_block_match = re.search(
        r"```[a-zA-Z0-9_\-]*\n(.*?)```", section_text, re.DOTALL
    )
    if code_block_match:
        return code_block_match.group(1)

    stop_match = re.search(
        r"\n(?=[A-Z][a-zA-Z0-9\s]+:\n|\#\#|\-\-\-|===)", section_text
    )
    if stop_match:
        section_text = section_text[: stop_match.start()]

    lines = section_text.splitlines()
    clean_lines = []
    code_started = False

    known_languages = {
        "python",
        "bash",
        "sh",
        "yaml",
        "yml",
        "json",
        "typescript",
        "javascript",
        "html",
        "css",
        "markdown",
        "toml",
        "sql",
    }

    for line in lines:
        sline = line.strip()
        if not code_started:
            if not sline:
                continue
            if sline.startswith("(") and sline.endswith(")"):
                continue
            if sline.lower() in known_languages:
                continue
            code_started = True

        if code_started:
            clean_lines.append(line)

    return "\n".join(clean_lines)


def write_files(extracted_files: list[tuple[str, str]], base_dir: Path):
    """Writes extracted code blocks to their target file paths."""
    if not extracted_files:
        print("⚠️  No file paths or code blocks recognized in the input.")
        return

    print(f"🚀 Base Directory: {base_dir}")
    print(f"🚀 Found {len(extracted_files)} file(s) to process:\n")

    for file_path_str, content in extracted_files:
        expanded_path = Path(os.path.expanduser(file_path_str))

        # Handle absolute or home-expanded paths vs relative paths
        if expanded_path.is_absolute():
            target_path = expanded_path
        else:
            clean_path = str(file_path_str).lstrip("/")
            target_path = base_dir / clean_path

        # Automatically create missing directory structures
        target_path.parent.mkdir(parents=True, exist_ok=True)

        # Write content
        target_path.write_text(content, encoding="utf-8")
        print(f"  ✓ Updated: {target_path}")

    print("\n✅ All file changes successfully applied!")


def get_input_text() -> str:
    """Reads input prioritizing CLI arg -> stdin pipe -> wl-paste clipboard."""
    if len(sys.argv) > 1:
        input_file = Path(sys.argv[1])
        if not input_file.exists():
            print(f"❌ Error: File '{input_file}' not found.")
            sys.exit(1)
        return input_file.read_text(encoding="utf-8")

    if not sys.stdin.isatty():
        return sys.stdin.read()

    print("📋 Reading content directly from Wayland clipboard...")

    if not shutil.which("wl-paste"):
        print("❌ Error: 'wl-paste' command not found. Please install 'wl-clipboard'.")
        sys.exit(1)

    try:
        result = subprocess.run(
            ["wl-paste"], capture_output=True, text=True, check=True
        )
        if not result.stdout.strip():
            print("⚠️ Clipboard is empty.")
            sys.exit(0)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"❌ Error reading clipboard via wl-paste: {e}")
        sys.exit(1)


def main():
    # Detects current working directory, preserving symlinked path structures ($PWD)
    base_dir = Path(os.environ.get("PWD", os.getcwd()))
    raw_text = get_input_text()
    files = extract_files_from_markdown(raw_text)
    write_files(files, base_dir)


if __name__ == "__main__":
    main()
