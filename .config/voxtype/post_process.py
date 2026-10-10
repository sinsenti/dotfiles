#!/usr/bin/env python3
"""Route spoken translation searches to the browser; normalize other dictation."""

import re
import subprocess
import sys
from urllib.parse import urlencode

from stop_commands import remove_stop_command


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
    text = remove_stop_command(text)
    url = search_url(text)
    if url and open_search(url):
        return ""  # Browser commands must not also be pasted into its new window.
    return text.strip().lower().rstrip(".")


if __name__ == "__main__":
    sys.stdout.write(process(sys.stdin.read()))
