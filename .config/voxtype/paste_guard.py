#!/usr/bin/env python3
"""Choose Kitty's paste shortcut or the existing shortcut for other GUI apps."""

import json
from pathlib import Path
import re


TERMINALS = {
    "kitty", "alacritty", "wezterm", "ghostty", "foot", "footclient",
    "konsole", "gnome-terminal", "gnome-terminal-server", "kgx",
    "console", "ptyxis", "tilix", "terminator", "xterm", "uxterm",
    "urxvt", "rxvt", "st", "st-256color", "xfce4-terminal",
    "mate-terminal", "guake", "tilda", "terminal",
}


def is_terminal_name(name):
    if not isinstance(name, str):
        return False
    name = name.casefold()
    return name in TERMINALS or any(
        part in TERMINALS for part in re.split(r"[._]", name)
    )


def paste_target(windows):
    if not isinstance(windows, list):
        return None
    focused = [w for w in windows if isinstance(w, dict)
               and (w.get("focus") is True or w.get("has_focus") is True)]
    if len(focused) != 1:
        return None
    window = focused[0]
    names = [window.get("wm_class"), window.get("wm_class_instance")]
    # Custom window classes (e.g. a Kitty notes window) still have a terminal PID.
    pid = window.get("pid")
    if isinstance(pid, int) and not isinstance(pid, bool) and pid > 1:
        try:
            names.append(Path(f"/proc/{pid}/comm").read_text().strip())
        except OSError:
            pass
    names = [name for name in names if isinstance(name, str) and name.strip()]
    if any("kitty" in re.split(r"[._]", name.casefold()) for name in names):
        return "kitty"
    if not names or any(is_terminal_name(name) for name in names):
        return None
    return "gui"


def focused_windows():
    import gi

    gi.require_version("Gio", "2.0")
    from gi.repository import Gio, GLib

    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    result = bus.call_sync(
        "org.gnome.Shell", "/org/gnome/Shell/Extensions/Windows",
        "org.gnome.Shell.Extensions.Windows", "List", None,
        GLib.VariantType.new("(s)"), Gio.DBusCallFlags.NONE, 1000, None,
    )
    return json.loads(result.unpack()[0])


def main():
    try:
        windows = focused_windows()
    except Exception:
        # No focus information: retain the clipboard without injecting a shortcut.
        return 1
    target = paste_target(windows)
    if target is None:
        return 1
    print(target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
