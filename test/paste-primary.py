#!/usr/bin/env python3
"""Exercise middle click selection fallback and tmux failure handling."""
from importlib.machinery import SourceFileLoader
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
source = str(Path(__file__).resolve().parents[1] / "bin/paste-primary")
spec = importlib.util.spec_from_loader("paste_primary", SourceFileLoader("paste_primary", source))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def result(text=b"", status=0):
    return SimpleNamespace(stdout=text, returncode=status)


class PasteTests(unittest.TestCase):
    def test_primary_preserves_bytes_and_uses_bracketed_paste(self):
        text = "hello 'quotes' $variables\n世界\n\n".encode()
        with patch.object(helper, "run", side_effect=[result(text), result(), result(), result()]) as run:
            self.assertIsNone(helper.paste("%3"))
            self.assertEqual(run.call_count, 4)
            self.assertEqual(run.call_args_list[1].args[-1].encode(), text)
            self.assertEqual(run.call_args_list[2].args[:3], ("tmux", "paste-buffer", "-p"))
            self.assertEqual(run.call_args_list[2].args[-2:], ("-t", "%3"))

    def test_empty_or_unavailable_primary_falls_back(self):
        for primary in (result(), result(status=1)):
            with patch.object(helper, "run", side_effect=[primary, result(b"clipboard"), result(), result(), result()]) as run:
                self.assertIsNone(helper.paste("%3"))
                self.assertEqual(run.call_args_list[1].args[2], "clipboard")
                self.assertEqual(run.call_args_list[2].args[-1], "clipboard")

    def test_empty_clipboards_do_not_load_or_paste(self):
        with patch.object(helper, "run", side_effect=[result(), result()]) as run:
            self.assertIn("No text", helper.paste("%3"))
            self.assertEqual(run.call_count, 2)

    def test_paste_failure_cleans_buffer(self):
        with patch.object(helper, "run", side_effect=[result(b"text"), result(), result(status=1), result()]) as run:
            self.assertIn("Could not paste", helper.paste("%3"))
            self.assertEqual(run.call_args.args[:2], ("tmux", "delete-buffer"))

    def test_error_uses_status_instead_of_failure_viewer(self):
        with (patch.object(sys, "argv", ["paste-primary", "%3"]),
              patch.object(helper, "paste", return_value="No text"),
              patch.object(helper, "run") as run):
            self.assertEqual(helper.main(), 0)
            self.assertEqual(run.call_args.args, ("tmux", "display-message", "-t", "%3", "-d", "5000", "-l", "No text"))


if __name__ == "__main__":
    unittest.main()
