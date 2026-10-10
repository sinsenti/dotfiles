#!/usr/bin/env python3
"""A focus-free GNOME status window for Voxtype's state_file = 'auto'."""

import os
from pathlib import Path
import signal
import time


class StatusModel:
    """Keep idle hidden and show a brief completion/cancellation message."""

    def __init__(self):
        self.previous = "idle"
        self.message = None
        self.hide_at = 0.0

    def update(self, state, now):
        if state == "recording":
            self.message = ("recording", "Recording", "Listening to your voice")
        elif state == "transcribing":
            self.message = ("transcribing", "Transcribing", "Turning speech into text")
        elif state == "idle" and self.previous == "transcribing":
            self.message = ("done", "Done", "Ready for your next recording")
            self.hide_at = now + 1.5
        elif state == "idle" and self.previous == "recording":
            self.message = ("cancelled", "Recording ended", "Ready for your next recording")
            self.hide_at = now + 1.5
        elif state == "stopped" and self.previous in ("recording", "transcribing"):
            self.message = ("cancelled", "Voxtype stopped", "Recording is no longer active")
            self.hide_at = now + 2.0
        elif state not in ("idle", "stopped"):
            self.message = None

        if state in ("idle", "stopped") and now >= self.hide_at:
            self.message = None
        self.previous = state
        return self.message


def read_state(directory):
    try:
        pid = int((directory / "pid").read_text().strip())
        if pid <= 1:
            return "stopped"
        try:
            os.kill(pid, 0)
        except PermissionError:
            pass  # A live process can exist even if signal permission is denied.
        return (directory / "state").read_text().strip()
    except (OSError, ValueError):
        return "stopped"


def main():
    # Native Wayland windows cannot request absolute placement on GNOME.
    os.environ.setdefault("GDK_BACKEND", "x11")
    import gi

    gi.require_version("Gtk", "3.0")
    gi.require_version("Gdk", "3.0")
    from gi.repository import Gdk, Gio, GLib, Gtk

    if not Gtk.init_check()[0]:
        raise SystemExit("Voxtype status window: cannot connect to the graphical display")

    # An unmanaged popup avoids GNOME's normal window map/unmap effects.
    Gtk.Settings.get_default().set_property("gtk-enable-animations", False)
    window = Gtk.Window(type=Gtk.WindowType.POPUP, title="Voxtype status")
    window.set_decorated(False)
    window.set_resizable(False)
    window.set_accept_focus(False)
    window.set_focus_on_map(False)
    window.set_keep_above(True)
    window.set_skip_taskbar_hint(True)
    window.set_skip_pager_hint(True)
    window.set_type_hint(Gdk.WindowTypeHint.TOOLTIP)
    window.stick()
    window.set_name("voxtype-status")
    visual = window.get_screen().get_rgba_visual()
    if visual:
        window.set_visual(visual)

    css = Gtk.CssProvider()
    css.load_from_data(b"""
        #voxtype-status { background: #1e1e2e; border: 1px solid #45475a;
                          border-radius: 12px; box-shadow: none; transition: none; }
        #voxtype-status label { color: #cdd6f4; }
        #voxtype-status .title { font-size: 16px; font-weight: bold; }
        #voxtype-status .detail { font-size: 12px; color: #a6adc8; }
        #voxtype-status .indicator { font-size: 24px; }
        #voxtype-status.recording .indicator { color: #f38ba8; }
        #voxtype-status.transcribing .indicator { color: #f9e2af; }
        #voxtype-status.done .indicator { color: #a6e3a1; }
        #voxtype-status.cancelled .indicator { color: #a6adc8; }
    """)
    Gtk.StyleContext.add_provider_for_screen(
        window.get_screen(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )
    row = Gtk.Box(spacing=14)
    row.set_border_width(18)
    indicator = Gtk.Label(label="●")
    indicator.get_style_context().add_class("indicator")
    row.pack_start(indicator, False, False, 0)
    text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    title = Gtk.Label(xalign=0)
    title.get_style_context().add_class("title")
    detail = Gtk.Label(xalign=0)
    detail.get_style_context().add_class("detail")
    text.pack_start(title, False, False, 0)
    text.pack_start(detail, False, False, 0)
    row.pack_start(text, True, True, 0)
    window.add(row)

    def position():
        display = window.get_display()
        monitor = display.get_primary_monitor() or display.get_monitor(0)
        if monitor:
            area = monitor.get_workarea()
            width, height = window.get_size()
            window.move(area.x + (area.width - width) // 2,
                        area.y + max(0, area.height - height - 48))

    # Ask GDK to pass pointer events through this display-only window.
    def mapped(widget, _event):
        widget.get_window().set_pass_through(True)
        position()

    window.connect("map-event", mapped)
    window.connect("size-allocate", lambda *_: position())
    window.connect("destroy", lambda *_: Gtk.main_quit())

    directory = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "voxtype"
    model = StatusModel()
    last_message = None

    def refresh():
        nonlocal last_message
        state = read_state(directory)
        if not state:  # The daemon may be between truncating and writing the file.
            return GLib.SOURCE_CONTINUE
        message = model.update(state, time.monotonic())
        if message != last_message:
            if message is None:
                window.hide()
            else:
                state, heading, subtitle = message
                context = window.get_style_context()
                for name in ("recording", "transcribing", "done", "cancelled"):
                    context.remove_class(name)
                context.add_class(state)
                title.set_text(heading)
                detail.set_text(subtitle)
                indicator.set_text("✓" if state == "done" else "●")
                window.show_all()  # Never use present(), which requests focus.
            last_message = message
        return GLib.SOURCE_CONTINUE

    # File events catch short transcriptions; polling also handles startup,
    # process exits, missing directories and the completion-message timer.
    try:
        watcher = Gio.File.new_for_path(str(directory)).monitor_directory(
            Gio.FileMonitorFlags.NONE, None
        )
        watcher.set_rate_limit(0)
        watcher.connect("changed", lambda *_: refresh())
    except GLib.Error:
        watcher = None
    GLib.timeout_add(150, refresh)
    for signum in (signal.SIGTERM, signal.SIGINT):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signum, Gtk.main_quit)
    refresh()
    Gtk.main()


if __name__ == "__main__":
    main()
