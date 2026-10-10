"""Submission regression checks with keyboard and browser operations mocked."""

import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

import paste_delivery
import post_process
from stop_commands import STOP_PHRASES, SUBMIT_PHRASES


class SubmitTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.request = self.directory / "submit-request.json"
        self.spoken = self.directory / "spoken-stop.json"
        for module in ("post_process", "paste_delivery", "stop_commands"):
            mock = patch(module + ".runtime_directory", return_value=self.directory)
            mock.start()
            self.addCleanup(mock.stop)

    def speak(self, phrase):
        self.spoken.write_text(json.dumps({"phrase": phrase, "time": time.time()}))

    def test_submit_commands_strip_suffix_and_queue_one_enter(self):
        for phrase in SUBMIT_PHRASES:
            self.speak(phrase)
            self.assertEqual(post_process.process("Hello world. " + phrase.upper() + "!"), "hello world")
            self.assertTrue(paste_delivery.take_request())
            self.assertFalse(paste_delivery.take_request())

    def test_normal_stop_and_manual_dictation_never_submit(self):
        for phrase in STOP_PHRASES:
            self.speak(phrase)
            self.assertEqual(post_process.process("Hello. " + phrase), "hello")
            self.assertFalse(self.request.exists())
        self.assertEqual(post_process.process("hello send message"), "hello send message")
        self.assertFalse(self.request.exists())

    def test_empty_or_mismatched_transcript_never_submits_existing_input(self):
        for phrase in SUBMIT_PHRASES:
            self.speak(phrase)
            self.assertEqual(post_process.process(phrase), "")
            self.assertFalse(self.request.exists())
        self.speak(SUBMIT_PHRASES[0])
        post_process.process("hello stop recording")
        self.assertFalse(self.request.exists())

    def test_browser_route_consumes_command_without_enter(self):
        self.speak(SUBMIT_PHRASES[0])
        with patch("post_process.open_search", return_value=True) as browser:
            self.assertEqual(post_process.process("translate hello submit text"), "")
            self.assertNotIn("submit", browser.call_args.args[0])
        self.assertFalse(self.request.exists())

    def test_stale_requests_are_discarded(self):
        self.request.write_text(json.dumps({"action": "submit", "time": 0}))
        self.assertFalse(paste_delivery.take_request(now=11))
        self.assertFalse(self.request.exists())

    def test_successful_paste_then_enter_once(self):
        self.speak(SUBMIT_PHRASES[0])
        post_process.process("Hello submit text")
        with patch("paste_delivery.focused_identity", return_value=(123, 456)):
            with patch("paste_delivery.time.sleep"), patch("paste_delivery.subprocess.run") as keyboard:
                keyboard.return_value.returncode = 0
                self.assertEqual(paste_delivery.deliver(["key", "ctrl+shift+v"]), 0)
                self.assertEqual(keyboard.call_args_list[0].args[0], ["/usr/bin/ydotool", "key", "ctrl+shift+v"])
                self.assertEqual(keyboard.call_args_list[1].args[0][-3:], ["key", "28:1", "28:0"])
                self.assertEqual(keyboard.call_count, 2)
                keyboard.reset_mock()
                paste_delivery.deliver(["key", "ctrl+v"])
                self.assertEqual(keyboard.call_count, 1)

    def test_failed_paste_changed_or_unknown_focus_never_enters(self):
        for returncode, identities in ((1, [(123, 456)]), (0, [(123, 456), (789, 456)]), (0, [None])):
            self.speak(SUBMIT_PHRASES[0])
            post_process.process("Hello submit text")
            with patch("paste_delivery.focused_identity", side_effect=identities):
                with patch("paste_delivery.time.sleep"), patch("paste_delivery.subprocess.run") as keyboard:
                    keyboard.return_value.returncode = returncode
                    self.assertEqual(paste_delivery.deliver(["key", "ctrl+v"]), returncode)
                    self.assertEqual(keyboard.call_count, 1)
                    self.assertFalse(self.request.exists())

    def test_enter_failure_does_not_retry_successful_paste(self):
        self.speak(SUBMIT_PHRASES[0])
        post_process.process("Hello submit text")
        with patch("paste_delivery.focused_identity", return_value=(123, 456)):
            with patch("paste_delivery.time.sleep"), patch("paste_delivery.subprocess.run") as keyboard:
                from subprocess import CompletedProcess

                keyboard.side_effect = [CompletedProcess([], 0), CompletedProcess([], 1)]
                self.assertEqual(paste_delivery.deliver(["key", "ctrl+v"]), 0)
                self.assertEqual(keyboard.call_count, 2)


if __name__ == "__main__":
    unittest.main()
