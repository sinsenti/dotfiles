#!/usr/bin/env python3
"""Paste through ydotool, then consume an optional one-shot Enter request."""

import json
from pathlib import Path
import subprocess
import sys
import time

from paste_guard import focused_windows, paste_target
from stop_commands import runtime_directory


def take_request(directory=None, now=None):
    marker = (directory or runtime_directory()) / "submit-request.json"
    try:
        request = json.loads(marker.read_text())
        marker.unlink()
        age = (time.time() if now is None else now) - request["time"]
        return request["action"] == "submit" and 0 <= age <= 10
    except (OSError, ValueError, KeyError, TypeError):
        return False


def focused_identity():
    try:
        windows = focused_windows()
        if paste_target(windows) not in ("gui", "kitty"):
            return None
        focused = [w for w in windows if isinstance(w, dict)
                   and (w.get("focus") is True or w.get("has_focus") is True)]
        window = focused[0]
        if window.get("id") is None or window.get("pid") is None:
            return None
        return window["id"], window["pid"]
    except Exception:
        return None


def deliver(arguments):
    submit = take_request()
    identity = focused_identity() if submit else None
    result = subprocess.run(["/usr/bin/ydotool", *arguments], check=False)
    if result.returncode != 0:
        return result.returncode
    if submit and identity is not None:
        # Allow the focused application to process the paste before Enter.
        time.sleep(0.25)
        if focused_identity() == identity:
            # The compatibility wrapper selects legacy symbolic or modern
            # numeric Enter without treating this as another paste attempt.
            wrapper = Path(__file__).parent / "bin/ydotool"
            entered = subprocess.run([str(wrapper), "key", "28:1", "28:0"], check=False)
            if entered.returncode != 0:
                print("Voxtype: text pasted but Enter failed", file=sys.stderr)
            # Paste already succeeded; never invite a duplicate paste retry.
            return 0
        print("Voxtype: focus changed after paste; submission skipped", file=sys.stderr)
    return 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--discard"]:
        take_request()
    else:
        raise SystemExit(deliver(sys.argv[1:]))
