"""Shared spoken-stop phrases and one-shot transcript cleanup."""

import json
import os
from pathlib import Path
import re
import time


STOP_PHRASES = ("stop recording", "end dictation", "finish recording", "конец записи")
SUBMIT_PHRASES = ("submit text", "send message", "отправить текст")
PHRASES = (*STOP_PHRASES, *SUBMIT_PHRASES)
MODELS = ("vosk-model-small-en-us-0.15", "vosk-model-small-ru-0.22")
# Competing phrases keep similar technical dictation out of the commands.
GRAMMARS = (
    (*STOP_PHRASES[:3], *SUBMIT_PHRASES[:2], "finish coding", "stop coding", "start recording", "send dictation", "[unk]"),
    (STOP_PHRASES[3], SUBMIT_PHRASES[2], "конец задачи", "конец запаса", "открыть текст", "[unk]"),
)
SUFFIX = re.compile(
    r"(?<!\w)(?:" + "|".join(re.escape(p).replace(r"\ ", r"\s+") for p in PHRASES)
    + r")[\s.!?,;:…]*$", re.IGNORECASE,
)


def data_directory():
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "voxtype/stop-commands"


def runtime_directory():
    return Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "voxtype"


def recognized_command(result):
    """Require an isolated complete command, rather than a partial guess."""
    words = result.get("result", [])
    for phrase in PHRASES:
        tokens = phrase.split()
        if [word.get("word") for word in words] == tokens and all(
            word.get("conf", 0) >= 0.75 for word in words
        ):
            return phrase
    return None


def consume_spoken_command(text, directory=None, now=None):
    """Return cleaned text and the command that actually stopped recording."""
    marker = (directory or runtime_directory()) / "spoken-stop.json"
    try:
        event = json.loads(marker.read_text())
        marker.unlink()
        age = (time.time() if now is None else now) - event["time"]
        if event["phrase"] in PHRASES and 0 <= age <= 180:
            match = SUFFIX.search(text)
            if match and " ".join(re.findall(r"\w+", match.group().casefold())) == event["phrase"]:
                return text[:match.start()].rstrip(" \t\r\n,;:"), event["phrase"]
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return text, None


def remove_stop_command(text, directory=None, now=None):
    return consume_spoken_command(text, directory, now)[0]
