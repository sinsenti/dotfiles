"""Offline checks; never access the microphone, clipboard, or live daemon."""

import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import post_process
from stop_commands import PHRASES, recognized_command, remove_stop_command
from stop_listener import StopListener


def recognition(text, confidence=1):
    return {"result": [{"word": word, "conf": confidence} for word in text.split()]}


class SpokenStopTests(unittest.TestCase):
    def test_only_complete_isolated_confident_commands_stop(self):
        for phrase in PHRASES:
            self.assertEqual(recognized_command(recognition(phrase)), phrase)
            self.assertIsNone(recognized_command(recognition(phrase, 0.5)))
            self.assertIsNone(recognized_command(recognition("message " + phrase)))
            self.assertIsNone(recognized_command(recognition(phrase + " later")))
        for text in ("finish", "finish coding", "start recording", "[unk]", "конец задачи"):
            self.assertIsNone(recognized_command(recognition(text)))

    def test_cleanup_is_one_shot_and_requires_a_recent_spoken_stop(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            marker = directory / "spoken-stop.json"
            for phrase in PHRASES:
                text = "Message. " + phrase.upper() + "!"
                self.assertEqual(remove_stop_command(text, directory, now=100), text)
                marker.write_text(json.dumps({"phrase": phrase, "time": 99}))
                self.assertEqual(remove_stop_command(text, directory, now=100), "Message.")
                self.assertFalse(marker.exists())
                self.assertEqual(remove_stop_command(text, directory, now=100), text)
                marker.write_text(json.dumps({"phrase": phrase, "time": 99}))
                self.assertEqual(remove_stop_command(phrase, directory, now=100), "")
            marker.write_text(json.dumps({"phrase": PHRASES[0], "time": 0}))
            self.assertEqual(remove_stop_command("stop recording", directory, now=200), "stop recording")
            marker.write_text("{invalid")
            self.assertEqual(remove_stop_command("message", directory), "message")

    def test_stop_command_does_not_reach_browser_search(self):
        with tempfile.TemporaryDirectory() as temporary:
            with patch("post_process.runtime_directory", return_value=Path(temporary)):
                with patch("post_process.consume_spoken_command", return_value=("translate hello", PHRASES[0])):
                    with patch("post_process.open_search", return_value=True) as browser:
                        self.assertEqual(post_process.process("translate hello stop recording"), "")
                        self.assertNotIn("stop", browser.call_args.args[0])

    def test_stop_only_signals_recording_and_cleans_failed_marker(self):
        with tempfile.TemporaryDirectory() as temporary:
            listener = StopListener([], None)
            listener.directory = Path(temporary)
            listener.marker = listener.directory / "spoken-stop.json"
            try:
                with patch("stop_listener.read_state", return_value="idle"):
                    with patch("stop_listener.subprocess.run") as signal:
                        self.assertFalse(listener.stop_recording(PHRASES[0]))
                        signal.assert_not_called()
                with patch("stop_listener.read_state", return_value="recording"):
                    with patch("stop_listener.subprocess.run") as signal:
                        signal.return_value.returncode = 0
                        self.assertTrue(listener.stop_recording(PHRASES[0]))
                        self.assertEqual(signal.call_args.args[0], ["voxtype", "record", "stop"])
                        self.assertEqual(json.loads(listener.marker.read_text())["phrase"], PHRASES[0])
                        signal.return_value.returncode = 1
                        self.assertFalse(listener.stop_recording(PHRASES[1]))
                        self.assertFalse(listener.marker.exists())
            finally:
                listener.selector.close()

    def test_idle_never_opens_audio(self):
        listener = StopListener([], None)

        def shutdown(_):
            listener.running = False

        with patch("stop_listener.read_state", return_value="idle"):
            with patch.object(listener, "start_capture") as capture:
                with patch("stop_listener.time.sleep", side_effect=shutdown):
                    listener.run()
                capture.assert_not_called()


if __name__ == "__main__":
    unittest.main()
