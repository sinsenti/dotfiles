#!/usr/bin/env python3
"""Detect spoken stop phrases locally, capturing audio only while recording."""

import json
import os
import selectors
import signal
import subprocess
import sys
import time

from stop_commands import GRAMMARS, MODELS, data_directory, recognized_command, runtime_directory
from status_window import read_state


class StopListener:
    def __init__(self, models, recognizer):
        self.models = models
        self.recognizer = recognizer
        self.directory = runtime_directory()
        self.marker = self.directory / "spoken-stop.json"
        self.capture = None
        self.selector = selectors.DefaultSelector()
        self.recognizers = []
        self.previous = None
        self.stopping = False
        self.running = True
        self.retry_at = 0

    def close_capture(self):
        if self.capture:
            self.selector.unregister(self.capture.stdout)
            self.capture.terminate()
            try:
                self.capture.wait(timeout=1)
            except subprocess.TimeoutExpired:
                self.capture.kill()
                self.capture.wait()
            self.capture.stdout.close()
            self.capture = None
        self.recognizers = []

    def start_capture(self):
        self.recognizers = []
        for model, phrases in zip(self.models, GRAMMARS):
            # Unknown speech must remain rejectable rather than being forced
            # into the command vocabulary. Preserve actual Russian UTF-8.
            grammar = json.dumps(phrases, ensure_ascii=False)
            recognizer = self.recognizer(model, 16000, grammar)
            recognizer.SetWords(True)
            self.recognizers.append(recognizer)
        self.capture = subprocess.Popen(
            ["parec", "--raw", "--device=@DEFAULT_SOURCE@", "--rate=16000",
             "--channels=1", "--format=s16le", "--latency-msec=100",
             "--client-name=Voxtype stop commands"],
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, bufsize=0,
        )
        self.selector.register(self.capture.stdout, selectors.EVENT_READ)

    def stop_recording(self, phrase):
        if read_state(self.directory) != "recording":
            return False
        # Write before signalling: transcription may finish immediately.
        self.marker.write_text(json.dumps({"phrase": phrase, "time": time.time()}))
        try:
            result = subprocess.run(
                ["voxtype", "record", "stop"], stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2,
            )
            if result.returncode != 0:
                self.marker.unlink(missing_ok=True)
                return False
        except (OSError, subprocess.TimeoutExpired):
            self.marker.unlink(missing_ok=True)
            return False
        return True

    def run(self):
        try:
            while self.running:
                state = read_state(self.directory)
                if state != "recording":
                    self.close_capture()
                    self.stopping = False
                elif self.previous != "recording":
                    self.marker.unlink(missing_ok=True)
                    self.stopping = False
                    self.retry_at = 0
                self.previous = state
                if state == "recording" and not self.stopping and not self.capture and time.monotonic() >= self.retry_at:
                    try:
                        self.start_capture()
                    except OSError:
                        print("Voxtype stop listener: cannot open microphone; retrying", file=sys.stderr, flush=True)
                        self.retry_at = time.monotonic() + 5
                if not self.capture:
                    time.sleep(0.1)
                    continue
                if not self.selector.select(timeout=0.1):
                    continue
                chunk = os.read(self.capture.stdout.fileno(), 3200)
                if not chunk:
                    self.close_capture()
                    self.retry_at = time.monotonic() + 5
                    print("Voxtype stop listener: audio stream ended; retrying", file=sys.stderr, flush=True)
                    continue
                if read_state(self.directory) != "recording":
                    self.close_capture()
                    continue
                for recognizer in self.recognizers:
                    # Wait for an utterance boundary (brief silence), never a partial guess.
                    if recognizer.AcceptWaveform(chunk):
                        phrase = recognized_command(json.loads(recognizer.Result()))
                        if phrase and self.stop_recording(phrase):
                            self.stopping = True
                            self.close_capture()
                            break
        finally:
            self.close_capture()
            self.selector.close()


def main():
    from vosk import KaldiRecognizer, Model, SetLogLevel

    SetLogLevel(-1)
    models = [Model(str(data_directory() / name)) for name in MODELS]
    listener = StopListener(models, KaldiRecognizer)

    def shutdown(*_):
        listener.running = False

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    print("Voxtype stop listener: ready (English and Russian)", flush=True)
    listener.run()


if __name__ == "__main__":
    main()
