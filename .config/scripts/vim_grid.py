#!/usr/bin/env python3

import os
import sys
import subprocess

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QColor, QPainter, QPen
from PyQt6.QtWidgets import QApplication, QWidget


class WarpGrid(QWidget):
    SHRINK_FACTOR = 0.35
    MIN_SIZE = 12

    def __init__(self):
        super().__init__()

        screen = QApplication.primaryScreen()
        rect = screen.availableGeometry()

        self.screen_w = rect.width()
        self.screen_h = rect.height()

        print("SCREEN LOGICAL RES:", self.screen_w, self.screen_h)
        logical_cx = self.screen_w // 2
        logical_cy = self.screen_h // 2
        print("LOGICAL CENTER:", logical_cx, logical_cy)

        # CALIBRATION FACTOR VALUES
        # Maps your logical center (960, 540) to your hardware ydotool center (1355, 820)
        self.scale_x = 1355 / logical_cx
        self.scale_y = 820 / logical_cy

        self.xmin = 0
        self.ymin = 0
        self.xmax = self.screen_w
        self.ymax = self.screen_h

        self.history = []

        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint
        )

        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setGeometry(0, 0, self.screen_w, self.screen_h)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)

        # Set up a unified environment mapping the socket for ydotool execution
        self.ydotool_env = os.environ.copy()
        self.ydotool_env["YDOTOOL_SOCKET"] = "/tmp/ydotoold.socket"

        self.update_center()

    def update_center(self):
        self.cx = (self.xmin + self.xmax) // 2
        self.cy = (self.ymin + self.ymax) // 2

    def push_history(self):
        self.history.append(
            (
                self.xmin,
                self.ymin,
                self.xmax,
                self.ymax,
            )
        )

    def undo(self):
        if not self.history:
            return

        (
            self.xmin,
            self.ymin,
            self.xmax,
            self.ymax,
        ) = self.history.pop()

        self.update_center()
        self.update()

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

    def move_pointer(self):
        # --- Multi-Point Calibration Map ---
        logical_x_center = 960
        hardware_x_center = 1355

        logical_y_center = 524
        hardware_y_center = 820

        # X scales consistently across the axis
        calibrated_x = int(self.cx * (hardware_x_center / logical_x_center))

        # Y mapping splits at the center line to prevent coordinate overflow
        if self.cy <= logical_y_center:
            calibrated_y = int(self.cy * (hardware_y_center / logical_y_center))
        else:
            calibrated_y = hardware_y_center + int(
                (self.cy - logical_y_center)
                * (hardware_y_center / logical_y_center)
                * 0.82
            )

        print(
            f"TRYING MOVE -> LOGICAL: {self.cx},{self.cy} | CALIBRATED: {calibrated_x},{calibrated_y}"
        )

        # 1. Clear out memory tracking by zeroing out using sudo with environment passed directly
        subprocess.run(
            [
                "sudo",
                "YDOTOOL_SOCKET=/tmp/ydotoold.socket",
                "ydotool",
                "mousemove",
                "-99999",
                "-99999",
            ],
            capture_output=True,
        )

        # 2. Fire the custom coordinates using sudo with environment passed directly
        subprocess.run(
            [
                "sudo",
                "YDOTOOL_SOCKET=/tmp/ydotoold.socket",
                "ydotool",
                "mousemove",
                str(calibrated_x),
                str(calibrated_y),
            ],
            capture_output=True,
        )

    def keyPressEvent(self, event):
        key = event.text().lower()

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

        if key == "u":
            self.undo()
            return

        # Trigger on Enter, Return, or Spacebar to click and close immediately
        if event.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter) or key == " ":
            print(f"FINAL POSITION MATRIX: {self.cx},{self.cy}")
            self.move_pointer()

            # Fire an automatic left click via sudo with environment passed directly
            subprocess.run(
                [
                    "sudo",
                    "YDOTOOL_SOCKET=/tmp/ydotoold.socket",
                    "ydotool",
                    "click",
                    "0xC0",
                ],
                capture_output=True,
            )
            self.close()
            return

        if event.key() == Qt.Key.Key_Escape:
            self.close()
            return

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        overlay = QColor(0, 0, 0, 40)
        painter.fillRect(self.rect(), overlay)

        pen = QPen(QColor(255, 80, 80))
        pen.setWidth(3)
        painter.setPen(pen)

        painter.drawRect(
            self.xmin, self.ymin, self.xmax - self.xmin, self.ymax - self.ymin
        )

        pen = QPen(QColor(255, 255, 255))
        pen.setWidth(2)
        painter.setPen(pen)

        painter.drawLine(self.cx - 20, self.cy, self.cx + 20, self.cy)
        painter.drawLine(self.cx, self.cy - 20, self.cx, self.cy + 20)

        painter.setBrush(QColor(255, 0, 0))
        painter.drawEllipse(self.cx - 6, self.cy - 6, 12, 12)


if __name__ == "__main__":
    app = QApplication(sys.argv)

    overlay = WarpGrid()
    overlay.show()
    overlay.raise_()
    overlay.activateWindow()
    overlay.setFocus()

    sys.exit(app.exec())
