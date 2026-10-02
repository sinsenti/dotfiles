#!/usr/bin/env python3
import sys
import os
import subprocess
from datetime import datetime

LOG_FILE = "/tmp/voxtype_smart_output.log"


def log(msg):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    formatted = f"[{timestamp}] {msg}\n"
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(formatted)
    except Exception:
        pass


log("=" * 60)
log("Execution started")

raw_input = sys.stdin.read()
log(f"Raw stdin received: {repr(raw_input)}")

raw_text = raw_input.strip()
if not raw_text:
    log("Input text is empty. Exiting.")
    sys.exit(0)

# Lowercase (handles UTF-8) and strip trailing periods
text = raw_text.lower().rstrip(".")
log(f"Normalized text: {repr(text)}")

words = text.split()
log(f"Tokenized words: {words}")

if not words:
    log("No words found after tokenization. Exiting.")
    sys.exit(0)

SUBMIT_WORDS = {"submit", "enter", "ввод", "энтер"}
COPY_WORDS = {"copy", "копия", "копировать", "скопировать"}

action = "none"

if words[0] in COPY_WORDS:
    action = "copy (prefix)"
    words = words[1:]
elif words[-1] in COPY_WORDS:
    action = "copy (suffix)"
    words = words[:-1]
elif words[-1] in SUBMIT_WORDS:
    action = "submit"
    words = words[:-1]

clean_text = " ".join(words).strip().rstrip(".")
log(f"Action selected: '{action}' | Clean text: {repr(clean_text)}")

# Return clean text to Voxtype daemon
sys.stdout.write(clean_text)
sys.stdout.flush()

if "submit" in action:
    env = dict(os.environ)
    uid = os.getuid()

    # Check candidates for existing socket files
    possible_sockets = [
        f"/run/user/{uid}/ydotool/socket",
        f"/run/user/{uid}/.ydotool_socket",
        "/run/ydotoold.socket",
        "/var/run/ydotoold.socket",
        "/tmp/.ydotool_socket",
    ]

    # Prioritize environment variable ONLY if the file exists on disk
    if "YDOTOOL_SOCKET" in env and os.path.exists(env["YDOTOOL_SOCKET"]):
        possible_sockets.insert(0, env["YDOTOOL_SOCKET"])

    valid_socket = None
    for sock in possible_sockets:
        if os.path.exists(sock):
            valid_socket = sock
            break

    if valid_socket:
        env["YDOTOOL_SOCKET"] = valid_socket
        log(f"Using active YDOTOOL_SOCKET: {valid_socket}")
    else:
        log("ERROR: No active ydotool socket found on disk!")

    escaped_text = subprocess.list2cmdline([clean_text])

    # Execute background steps and log status
    cmd = (
        f"echo \"[\$(date +'%Y-%m-%d %H:%M:%S.%3N')] Executing wl-copy...\" >> {LOG_FILE} && "
        f"wl-copy -- {escaped_text} 2>> {LOG_FILE} && "
        f"sleep 0.2 && "
        f"echo \"[\$(date +'%Y-%m-%d %H:%M:%S.%3N')] Executing ydotool Ctrl+V...\" >> {LOG_FILE} && "
        f"ydotool key 29:1 47:1 47:0 29:0 2>> {LOG_FILE} && "
        f"sleep 0.1 && "
        f"echo \"[\$(date +'%Y-%m-%d %H:%M:%S.%3N')] Executing ydotool Enter...\" >> {LOG_FILE} && "
        f"ydotool key 28:1 28:0 2>> {LOG_FILE} && "
        f"echo \"[\$(date +'%Y-%m-%d %H:%M:%S.%3N')] Submit sequence completed.\" >> {LOG_FILE}"
    )

    log(f"Spawning submit process: {cmd}")
    proc = subprocess.Popen(cmd, shell=True, env=env, start_new_session=True)
    log(f"Submit process spawned with PID {proc.pid}")

elif "copy" in action:
    escaped_text = subprocess.list2cmdline([clean_text])
    cmd = f"wl-copy -- {escaped_text} 2>> {LOG_FILE}"
    log(f"Spawning copy process: {cmd}")
    subprocess.Popen(cmd, shell=True, start_new_session=True)
else:
    log("Action is 'none'. Clipboard updated via Voxtype standard output.")

log("Script execution finished")
