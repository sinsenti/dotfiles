#!/usr/bin/env python3
"""Route spoken translation searches to the browser; normalize other dictation."""

import re
import subprocess
import sys
import json
import time
from urllib.parse import urlencode

from stop_commands import SUBMIT_PHRASES, consume_spoken_command, runtime_directory


SEARCH_PREFIX = re.compile(r"^(translate|переведи)[,:.!?]?\s+(.+)$", re.IGNORECASE | re.DOTALL)


def search_url(text):
    query = text.strip().rstrip(".")
    match = SEARCH_PREFIX.match(query)
    if not match or not match.group(2).strip():
        return None
    # Keep the spoken command in the query so the search retains translation intent.
    return "https://www.google.com/search?" + urlencode({"q": query})


def open_search(url):
    try:
        child = subprocess.Popen(
            ["xdg-open", url], stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        try:
            return child.wait(timeout=2) == 0
        except subprocess.TimeoutExpired:
            # Some browser launchers stay alive with the browser. Do not wait for
            # the window to close or kill the user's browser process.
            return True
    except OSError:
        return False


def process(text):
    request = runtime_directory() / "submit-request.json"
    request.unlink(missing_ok=True)
    text, phrase = consume_spoken_command(text)
    url = search_url(text)
    if url and open_search(url):
        return ""  # Browser commands must not also be pasted into its new window.
    text = text.strip().lower().rstrip(".")
    # Empty dictation must not submit pre-existing input. Browser searches own
    # their output and must not inject Enter into the newly opened browser.
    if text and phrase in SUBMIT_PHRASES:
        request.write_text(json.dumps({"action": "submit", "time": time.time()}))
    return text


if __name__ == "__main__":
    sys.stdout.write(process(sys.stdin.read()))
