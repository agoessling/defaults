#!/usr/bin/env python3
"""Check connection argument preservation and foreground process selection."""
import importlib.util
from importlib.machinery import SourceFileLoader
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import io

sys.dont_write_bytecode = True

source = str(Path(__file__).resolve().parents[1] / "bin/clip-to-remote")
spec = importlib.util.spec_from_loader("ssh_pane", SourceFileLoader("ssh_pane", source))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class ConnectionTests(unittest.TestCase):
    def test_shortcut_error_uses_status_line_without_generic_failure(self):
        for error in ("Focus a pane with one foreground SSH connection.",
                      "The clipboard does not contain a PNG image."):
            with (patch.object(sys, "argv", ["clip-to-remote", "--pane", "123", "--tmux-target", "%1"]),
                  patch.object(helper, "find_connection", return_value=["/tmp", "--", "alias"]),
                  patch.object(helper, "upload", side_effect=ValueError(error)),
                  patch.object(helper, "notify") as notify,
                  patch.object(sys, "stderr", new_callable=io.StringIO) as stderr):
                self.assertEqual(helper.main(), 0)
                self.assertEqual(stderr.getvalue(), "")
                notify.assert_called_once_with(f"Screenshot upload: {error}", "%1")

    def test_missing_connection_stops_before_reading_clipboard(self):
        with (patch.object(sys, "argv", ["clip-to-remote", "--pane", "123", "--tmux-target", "%1"]),
              patch.object(helper, "find_connection", side_effect=ValueError("Focus an SSH pane.")),
              patch.object(helper, "upload") as upload,
              patch.object(helper, "notify") as notify):
            self.assertEqual(helper.main(), 0)
            upload.assert_not_called()
            notify.assert_called_once_with("Screenshot upload: Focus an SSH pane.", "%1")

    def test_tmux_message_is_literal_and_targeted(self):
        with patch.object(helper.subprocess, "run") as run:
            run.return_value.returncode = 0
            helper.notify("Example #{pane_id}", "%1")
            self.assertEqual(run.call_args.args[0], [
                "tmux", "display-message", "-t", "%1", "-d", "5000", "-l", "Example #{pane_id}"])

    def test_options_and_remote_command(self):
        self.assertEqual(helper.connection_args([
            "/usr/bin/ssh", "-vvAt", "-p2222", "-i", "a key", "-F", "custom config",
            "-J", "jump", "-o", "HostName=example.com", "-L", "8080:localhost:80",
            "-l", "alice", "alias", "tmux", "attach"]),
            ["-p", "2222", "-i", "a key", "-F", "custom config", "-J", "jump",
             "-o", "HostName=example.com", "-l", "alice", "--", "alias"])

    def test_uri_and_double_dash(self):
        self.assertEqual(helper.connection_args(["ssh", "--", "ssh://user@[::1]:2222"]),
                         ["--", "ssh://user@[::1]:2222"])

    def test_non_interactive_and_unknown(self):
        for args in (["ssh", "-W", "host:22", "jump"], ["ssh", "-O", "exit", "host"],
                     ["ssh", "-s", "host", "sftp"], ["ssh"]):
            with self.assertRaises(ValueError):
                helper.connection_args(args)

    def test_process_selection(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def process(pid, parent, group, argv):
                path = root / str(pid)
                path.mkdir(exist_ok=True)
                (path / "stat").write_text(f"{pid} (name with ) spaces) S {parent} {group} 1 123 20 0")
                (path / "cmdline").write_bytes(b"\0".join(arg.encode() for arg in argv) + b"\0")
                (path / "cwd").symlink_to(root)

            process(10, 1, 10, ["bash"])
            process(20, 10, 20, ["ssh", "-J", "jump", "destination"])
            process(21, 20, 20, ["ssh", "-W", "destination:22", "jump"])
            process(30, 10, 30, ["ssh", "background"])
            self.assertEqual(helper.find_connection(10, root),
                             [str(root), "-J", "jump", "--", "destination"])
            process(22, 10, 20, ["ssh", "another"])
            with self.assertRaises(ValueError):
                helper.find_connection(10, root)
            for pid in (20, 21, 22):
                (root / str(pid) / "cmdline").write_bytes(b"bash\0")
            with self.assertRaises(ValueError):
                helper.find_connection(10, root)


if __name__ == "__main__":
    unittest.main()
