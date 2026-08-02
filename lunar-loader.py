#!/usr/bin/env python3
import os
import re
import subprocess
import sys

from PyQt6.QtCore import QThread, pyqtSignal, Qt, QTimer
from PyQt6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QLabel,
    QProgressBar, QPushButton, QTextEdit,
)

APP_DIR = os.path.dirname(os.path.abspath(__file__))
MAIN_SCRIPT = os.path.join(APP_DIR, "lunar-install.sh")

STAGES = [
    (re.compile(r"staged in prefix"),          5,  "Vape DLL staged"),
    (re.compile(r"Launching Lunar Client"),   10,  "Launching launcher..."),
    (re.compile(r"Launcher started"),         15,  "Launcher started"),
    (re.compile(r"Waiting for the game to launch"), 25, "Waiting for game launch..."),
    (re.compile(r"Still waiting for the game to start"), 30, "Waiting for game to start..."),
    (re.compile(r"Game process found"),       40,  "Game process found"),
    (re.compile(r"Killing Lunar Client launcher"), 45, "Killing launcher..."),
    (re.compile(r"Launcher killed"),          50,  "Launcher killed"),
    (re.compile(r"Waiting for the game to initialize"), 60, "Waiting for game init..."),
    (re.compile(r"Still waiting for the game to initialize"), 68, "Game still initializing..."),
    (re.compile(r"Game initialized"),         75,  "Game initialized"),
    (re.compile(r"Waiting 3s"),               80,  "Safe injection delay..."),
    (re.compile(r"Injecting Vape"),           85,  "Injecting Vape V4..."),
    (re.compile(r"LoadLibrary returned"),     90,  "DLL loaded"),
    (re.compile(r"Vape V4 injected"),         95,  "Vape V4 injected"),
    (re.compile(r"Monitoring game session"),  100, "Session active"),
    (re.compile(r"Game running"),             100, "Session active"),
]

ERRORS = [
    re.compile(r"Timed out"),
    re.compile(r"Injection failed"),
    re.compile(r"ERROR"),
    re.compile(r"not found"),
    re.compile(r"failed"),
]


class ScriptWorker(QThread):
    line_emitted = pyqtSignal(str)
    process_done = pyqtSignal(int)

    def run(self):
        proc = subprocess.Popen(
            ["bash", MAIN_SCRIPT],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            cwd=APP_DIR,
        )
        self.proc = proc
        for raw in proc.stdout:
            self.line_emitted.emit(raw.rstrip())
        proc.wait()
        self.process_done.emit(proc.returncode)

    def stop(self):
        try:
            self.proc.terminate()
        except Exception:
            pass


class LoaderWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Vapetux")
        self.setMinimumSize(520, 320)

        layout = QVBoxLayout(self)

        self.title = QLabel("Lunar Client + Vape V4")
        self.title.setStyleSheet("font-size: 18px; font-weight: bold;")
        self.title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.title)

        self.progress = QProgressBar(self)
        self.progress.setRange(0, 100)
        self.progress.setValue(0)
        self.progress.setFixedHeight(26)
        layout.addWidget(self.progress)

        self.status = QLabel("Starting...")
        self.status.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.status.setStyleSheet("font-size: 13px;")
        layout.addWidget(self.status)

        self.log = QTextEdit(self)
        self.log.setReadOnly(True)
        self.log.setMaximumHeight(140)
        self.log.setStyleSheet("font-family: monospace; font-size: 11px;")
        layout.addWidget(self.log)

        self.btn = QPushButton("Cancel", self)
        self.btn.clicked.connect(self.cancel)
        layout.addWidget(self.btn)

        self.worker = ScriptWorker(self)
        self.worker.line_emitted.connect(self.on_line)
        self.worker.process_done.connect(self.on_done)
        self.worker.start()

        self.stage_idx = -1
        self.failed = False

    def on_line(self, line):
        clean = re.sub(r"\[lunar-vape\] ", "", line)
        self.log.append(clean if clean else " ")
        self.log.verticalScrollBar().setValue(
            self.log.verticalScrollBar().maximum()
        )

        if not self.failed and any(e.search(line) for e in ERRORS):
            self.failed = True
            self.status.setText(line.replace("[lunar-vape] ", ""))
            self.status.setStyleSheet(
                "font-size: 13px; color: #c0392b; font-weight: bold;"
            )
            self.btn.setText("Close")
            return

        for i, (rx, pct, text) in enumerate(STAGES):
            if rx.search(line) and i > self.stage_idx:
                self.stage_idx = i
                self.progress.setValue(pct)
                self.status.setText(text)
                return

    def on_done(self, code):
        if not self.failed and code == 0:
            self.status.setText("Session ended. Closing...")
            self.btn.setText("Close")
            QTimer.singleShot(1500, QApplication.quit)
        else:
            if not self.failed:
                self.status.setText(f"Loader exited with code {code}")
            self.btn.setText("Close")

    def cancel(self):
        if self.worker.isRunning():
            self.worker.stop()
            self.worker.wait(3000)
        QApplication.quit()


def main():
    app = QApplication(sys.argv)
    win = LoaderWindow()
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
