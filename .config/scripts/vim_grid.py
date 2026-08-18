#!/usr/bin/env python3

import os
import sys

# Force Qt to run via XWayland to enable global cursor position querying
os.environ["QT_QPA_PLATFORM"] = "xcb"

import subprocess
import time

from PyQt6.QtCore import Qt, QTimer, QRectF
from PyQt6.QtGui import QColor, QPainter, QPen, QFont, QCursor
from PyQt6.QtWidgets import QApplication, QWidget

# ==========================================================
# CONFIGURATION
# ==========================================================
DEFAULT_MODE = "hint"  # Options: "normal", "grid", or "hint"
# ==========================================================


class WarpGrid(QWidget):
    SHRINK_FACTOR = 0.35
    MIN_SIZE = 12

    # Vertical pixel calibration offset
    Y_OFFSET = 30

    # Normal mode speed steps (pixels)
    NORMAL_STEP = 20
    FAST_STEP = 80
    SLOW_STEP = 4

    # Keys used to generate Hint Mode grid labels (9x9 = 81 targets)
    HINT_KEYS = "asdfghjkl"

    def __init__(self, mode=DEFAULT_MODE):
        super().__init__()

        self.mode = mode.lower()  # "grid", "normal", or "hint"

        screen = QApplication.primaryScreen()
        rect = screen.geometry()

        self.screen_w = rect.width()
        self.screen_h = rect.height()

        # Full screen bounds for grid mode
        self.xmin = 0
        self.ymin = 0
        self.xmax = self.screen_w
        self.ymax = self.screen_h

        # History stack for undo
        self.history = []

        # Hint mode input buffer
        self.hint_input = ""
        self.hints = self._generate_hints()

        # Default fallback position
        self.cx = self.screen_w // 2
        self.cy = self.screen_h // 2
        self.cursor_synced = False

        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint
        )

        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setGeometry(0, 0, self.screen_w, self.screen_h)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.setMouseTracking(True)

        # Environment mapping for ydotool execution
        self.ydotool_env = os.environ.copy()
        self.ydotool_env["YDOTOOL_SOCKET"] = os.environ.get(
            "YDOTOOL_SOCKET", "/tmp/.ydotool_socket"
        )

        # Pre-fetch GNOME settings at startup to eliminate lag during movement
        self.orig_profile, self.orig_speed = self._cache_gnome_settings()

        # Sync cursor position right after XWayland surface mapping
        QTimer.singleShot(25, self._sync_live_cursor)

    def _generate_hints(self):
        """Generates a 2D grid of 2-letter hint targets across the screen."""
        hints = []
        n_keys = len(self.HINT_KEYS)
        margin_x = 70
        margin_y = 60

        step_x = (self.screen_w - 2 * margin_x) / (n_keys - 1)
        step_y = (self.screen_h - 2 * margin_y) / (n_keys - 1)

        for row in range(n_keys):
            for col in range(n_keys):
                label = self.HINT_KEYS[row] + self.HINT_KEYS[col]
                x = int(margin_x + col * step_x)
                y = int(margin_y + row * step_y)
                hints.append({"label": label, "x": x, "y": y})
        return hints

    def _get_current_mouse_pos(self):
        """Fetches real-time physical mouse position via xdotool or QCursor fallback."""
        try:
            out = (
                subprocess.check_output(
                    ["xdotool", "getmouselocation"],
                    stderr=subprocess.DEVNULL,
                )
                .decode()
                .strip()
            )
            parts = dict(item.split(":") for item in out.split() if ":" in item)
            return int(parts["x"]), int(parts["y"])
        except Exception:
            pos = QCursor.pos()
            if pos.x() == 0 and pos.y() == 0:
                return self.screen_w // 2, self.screen_h // 2
            return pos.x(), pos.y()

    def _sync_live_cursor(self):
        """Syncs crosshair directly to live cursor position after window focus."""
        if self.cursor_synced:
            return

        mx, my = self._get_current_mouse_pos()
        if mx != 0 or my != 0:
            self.cx = mx
            self.cy = max(0, my - self.Y_OFFSET)
            self.cursor_synced = True
            self.update()

    def enterEvent(self, event):
        super().enterEvent(event)
        self._sync_live_cursor()

    def showEvent(self, event):
        super().showEvent(event)
        QTimer.singleShot(10, self._sync_live_cursor)

    def _cache_gnome_settings(self):
        """Pre-reads GNOME mouse acceleration profile once on launch."""
        try:
            profile = (
                subprocess.check_output(
                    [
                        "gsettings",
                        "get",
                        "org.gnome.desktop.peripherals.mouse",
                        "accel-profile",
                    ]
                )
                .decode()
                .strip()
                .strip("'\"")
            )
            speed = (
                subprocess.check_output(
                    [
                        "gsettings",
                        "get",
                        "org.gnome.desktop.peripherals.mouse",
                        "speed",
                    ]
                )
                .decode()
                .strip()
                .strip("'\"")
            )
            return profile, speed
        except Exception:
            return None, None

    def _run_ydotool(self, *args):
        """Fast helper to run ydotool directly using socket environment."""
        try:
            subprocess.run(
                ["ydotool", *args],
                env=self.ydotool_env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=True,
            )
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass

    def update_center(self):
        if self.mode == "grid":
            self.cx = (self.xmin + self.xmax) // 2
            self.cy = (self.ymin + self.ymax) // 2

    def push_history(self):
        if self.mode == "grid":
            self.history.append(("grid", (self.xmin, self.ymin, self.xmax, self.ymax)))
        elif self.mode == "normal":
            self.history.append(("normal", (self.cx, self.cy)))
        elif self.mode == "hint":
            self.history.append(("hint", (self.hint_input, self.cx, self.cy)))

    def undo(self):
        if not self.history:
            return

        prev_mode, state = self.history.pop()
        self.mode = prev_mode

        if self.mode == "grid":
            self.xmin, self.ymin, self.xmax, self.ymax = state
            self.update_center()
        elif self.mode == "normal":
            self.cx, self.cy = state
        elif self.mode == "hint":
            self.hint_input, self.cx, self.cy = state

        self.update()

    # --- Grid Mode Methods ---
    def shrink_left(self):
        width = self.xmax - self.xmin
        self.xmax -= int(width * self.SHRINK_FACTOR)

    def shrink_right(self):
        width = self.xmax - self.xmin
        self.xmin += int(width * self.SHRINK_FACTOR)

    def shrink_up(self):
        height = self.ymax - self.ymin
        self.ymax -= int(height * self.SHRINK_FACTOR)

    def shrink_down(self):
        height = self.ymax - self.ymin
        self.ymin += int(height * self.SHRINK_FACTOR)

    # --- Normal Mode Movement ---
    def move_normal(self, dx, dy):
        self.push_history()
        self.cx = max(0, min(self.screen_w, self.cx + dx))
        self.cy = max(0, min(self.screen_h, self.cy + dy))
        self.update()

    # --- Pointer & Click Execution ---
    def move_pointer(self):
        target_x = int(self.cx)
        target_y = int(self.cy) + self.Y_OFFSET

        print(f"MOVING POINTER -> TARGET PIXELS: {target_x},{target_y}")

        if self.orig_profile:
            subprocess.run(
                [
                    "gsettings",
                    "set",
                    "org.gnome.desktop.peripherals.mouse",
                    "accel-profile",
                    "flat",
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            subprocess.run(
                [
                    "gsettings",
                    "set",
                    "org.gnome.desktop.peripherals.mouse",
                    "speed",
                    "0.0",
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

        # 1. Reset mouse position to top-left corner (0,0)
        self._run_ydotool("mousemove", "--", "-99999", "-99999")

        # 2. Move directly to target coordinates
        self._run_ydotool("mousemove", "--", str(target_x), str(target_y))

    def _restore_gnome_settings_async(self):
        """Restores mouse settings in background non-blockingly."""
        if self.orig_profile:
            subprocess.Popen(
                [
                    "gsettings",
                    "set",
                    "org.gnome.desktop.peripherals.mouse",
                    "accel-profile",
                    self.orig_profile,
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        if self.orig_speed:
            subprocess.Popen(
                [
                    "gsettings",
                    "set",
                    "org.gnome.desktop.peripherals.mouse",
                    "speed",
                    self.orig_speed,
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

    def execute_click(self, button_code="0x40"):
        """Performs target positioning and clicks."""
        self.hide()
        QApplication.processEvents()

        self.move_pointer()

        btn = int(button_code, 16)
        self._run_ydotool("click", hex(btn))  # Down
        self._run_ydotool("click", hex(btn | 0x40))  # Up

        self._restore_gnome_settings_async()
        QApplication.quit()

    def keyPressEvent(self, event):
        key = event.text().lower()
        modifiers = event.modifiers()

        # Global Mode Switchers
        if key == "g":
            self.mode = "grid"
            self.xmin, self.ymin = 0, 0
            self.xmax, self.ymax = self.screen_w, self.screen_h
            self.update_center()
            self.update()
            return

        if key in ("v", "n"):
            self.mode = "normal"
            self.update()
            return

        if key == "x":
            self.mode = "hint"
            self.hint_input = ""
            self.update()
            return

        if key == "u":
            self.undo()
            return

        # --- HINT MODE CONTROLS ---
        if self.mode == "hint":
            if event.key() == Qt.Key.Key_Backspace:
                self.hint_input = self.hint_input[:-1]
                self.update()
                return

            if key and key in self.HINT_KEYS:
                self.hint_input += key

                # Check for exact hint label match
                matched = [h for h in self.hints if h["label"] == self.hint_input]
                if matched:
                    target = matched[0]
                    self.cx = target["x"]
                    self.cy = target["y"]
                    self.hint_input = ""
                    self.mode = "normal"  # Warp to target and enter normal mode
                    self.update()
                    return

                # If typed input matches no hint prefixes, reset input buffer
                valid_prefix = any(
                    h["label"].startswith(self.hint_input) for h in self.hints
                )
                if not valid_prefix:
                    self.hint_input = key

                self.update()
                return

        # --- GRID MODE CONTROLS ---
        elif self.mode == "grid":
            if key in ("h", "j", "k", "l"):
                self.push_history()
                for _ in range(2):
                    if key == "h":
                        self.shrink_left()
                    elif key == "l":
                        self.shrink_right()
                    elif key == "k":
                        self.shrink_up()
                    elif key == "j":
                        self.shrink_down()

                self.update_center()
                self.update()
                return

        # --- NORMAL MODE CONTROLS ---
        elif self.mode == "normal":
            if modifiers & Qt.KeyboardModifier.ShiftModifier:
                step = self.FAST_STEP
            elif (
                modifiers & Qt.KeyboardModifier.AltModifier
                or modifiers & Qt.KeyboardModifier.ControlModifier
            ):
                step = self.SLOW_STEP
            else:
                step = self.NORMAL_STEP

            if key in ("h", "j", "k", "l"):
                dx, dy = 0, 0
                if key == "h":
                    dx = -step
                elif key == "l":
                    dx = step
                elif key == "k":
                    dy = -step
                elif key == "j":
                    dy = step

                self.move_normal(dx, dy)
                return

        # Actions/Clicks (Works across all modes)
        if event.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter) or key in (
            " ",
            "f",
        ):
            self.execute_click("0x40")  # Left Click
            return

        if key == "r":
            self.execute_click("0x41")  # Right Click
            return

        if key == "m":
            self.execute_click("0x42")  # Middle Click
            return

        if event.key() == Qt.Key.Key_Escape:
            QApplication.quit()
            return

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        # Background dimming
        overlay = QColor(0, 0, 0, 45)
        painter.fillRect(self.rect(), overlay)

        # 1. Render Hint Mode Labels
        if self.mode == "hint":
            painter.setFont(QFont("Monospace", 10, QFont.Weight.Bold))
            badge_w, badge_h = 32, 22

            for h in self.hints:
                lbl = h["label"]

                # Filter unmatched hints when typing
                if self.hint_input and not lbl.startswith(self.hint_input):
                    continue

                bx = h["x"] - badge_w // 2
                by = h["y"] - badge_h // 2

                # Badge background
                badge_rect = QRectF(bx, by, badge_w, badge_h)
                bg_color = (
                    QColor(255, 180, 0, 240)
                    if self.hint_input
                    else QColor(25, 25, 30, 220)
                )
                border_color = (
                    QColor(255, 220, 100)
                    if self.hint_input
                    else QColor(0, 230, 255, 180)
                )

                painter.setBrush(bg_color)
                painter.setPen(QPen(border_color, 1.5))
                painter.drawRoundedRect(badge_rect, 4, 4)

                # Label text
                text_color = (
                    QColor(0, 0, 0) if self.hint_input else QColor(255, 255, 255)
                )
                painter.setPen(QPen(text_color))
                painter.drawText(badge_rect, Qt.AlignmentFlag.AlignCenter, lbl.upper())

        # 2. Render Grid Mode Box
        elif self.mode == "grid":
            pen = QPen(QColor(255, 80, 80))
            pen.setWidth(3)
            painter.setPen(pen)
            painter.drawRect(
                self.xmin,
                self.ymin,
                self.xmax - self.xmin,
                self.ymax - self.ymin,
            )

        # 3. Render Reticle (Common across modes)
        pen = QPen(QColor(255, 255, 255))
        pen.setWidth(2)
        painter.setPen(pen)

        painter.drawLine(self.cx - 20, self.cy, self.cx + 20, self.cy)
        painter.drawLine(self.cx, self.cy - 20, self.cx, self.cy + 20)

        # Center dot indicator
        if self.mode == "grid":
            dot_color = QColor(255, 0, 0)
        elif self.mode == "hint":
            dot_color = QColor(255, 180, 0)
        else:
            dot_color = QColor(0, 230, 255)

        painter.setBrush(dot_color)
        painter.drawEllipse(self.cx - 6, self.cy - 6, 12, 12)

        # Mode Indicator Banner (Top-Left Corner)
        painter.setFont(QFont("Monospace", 10, QFont.Weight.Bold))
        painter.setPen(QPen(QColor(255, 255, 255)))
        painter.drawText(
            20,
            35,
            f"MODE: {self.mode.upper()}  [x: Hint | g: Grid | n: Normal | Esc: Exit]",
        )


if __name__ == "__main__":
    app = QApplication(sys.argv)

    overlay = WarpGrid()
    overlay.show()
    overlay.raise_()
    overlay.activateWindow()
    overlay.setFocus()

    sys.exit(app.exec())
