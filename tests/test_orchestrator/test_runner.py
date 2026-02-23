"""tests/test_orchestrator/test_runner.py — Unit tests for orchestrator/runner.py"""
import subprocess
import sys
import threading
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from orchestrator.cancellation import CancellationError, CancellationToken
from orchestrator.runner import run_bash, stream_bash


def _make_proc_mock(returncode=0, stdout="", stderr="", stdout_lines=None):
    """Build a MagicMock that behaves like a completed subprocess.Popen context manager."""
    proc = MagicMock()
    proc.returncode = returncode
    proc.poll.return_value = returncode
    proc.communicate.return_value = (stdout, stderr)
    if stdout_lines is not None:
        proc.stdout = iter(stdout_lines)
    proc.wait.return_value = returncode
    # Context manager protocol
    proc.__enter__ = MagicMock(return_value=proc)
    proc.__exit__ = MagicMock(return_value=False)
    return proc


class TestRunBash(unittest.TestCase):
    def test_success_result_ok_is_true(self):
        proc = _make_proc_mock(returncode=0, stdout="output\n")
        with patch("subprocess.Popen", return_value=proc):
            result = run_bash(Path("/fake/script.sh"))
        self.assertTrue(result.ok)
        self.assertEqual(result.returncode, 0)

    def test_failure_result_ok_is_false(self):
        proc = _make_proc_mock(returncode=1, stderr="error\n")
        with patch("subprocess.Popen", return_value=proc):
            result = run_bash(Path("/fake/script.sh"))
        self.assertFalse(result.ok)
        self.assertEqual(result.returncode, 1)

    def test_stdout_captured_in_result(self):
        proc = _make_proc_mock(returncode=0, stdout="hello world\n")
        with patch("subprocess.Popen", return_value=proc):
            result = run_bash(Path("/fake/script.sh"))
        self.assertEqual(result.stdout, "hello world\n")

    def test_env_vars_passed_to_subprocess(self):
        env = {"MY_KEY": "my_value", "OTHER": "val"}
        proc = _make_proc_mock(returncode=0)
        with patch("subprocess.Popen", return_value=proc) as mock_popen:
            run_bash(Path("/fake/script.sh"), env=env)
        _, kwargs = mock_popen.call_args
        self.assertEqual(kwargs.get("env"), env)

    def test_extra_args_passed_to_subprocess(self):
        proc = _make_proc_mock(returncode=0)
        with patch("subprocess.Popen", return_value=proc) as mock_popen:
            run_bash(Path("/fake/script.sh"), "--phase=packages")
        call_args = mock_popen.call_args[0][0]
        self.assertIn("--phase=packages", call_args)

    def test_cancellation_terminates_subprocess_and_raises(self):
        token = CancellationToken()
        proc = MagicMock()
        proc.returncode = None
        call_count = [0]

        def poll_side():
            call_count[0] += 1
            if call_count[0] >= 2:
                token.set()
            return None if call_count[0] < 3 else 0

        proc.poll.side_effect = poll_side
        proc.wait.return_value = 0
        proc.__enter__ = MagicMock(return_value=proc)
        proc.__exit__ = MagicMock(return_value=False)

        with patch("subprocess.Popen", return_value=proc):
            with self.assertRaises(CancellationError):
                run_bash(Path("/fake/script.sh"), cancel_token=token)
        proc.terminate.assert_called_once()


class TestStreamBash(unittest.TestCase):
    def test_yields_lines_in_order(self):
        proc = _make_proc_mock(
            returncode=0,
            stdout_lines=["line1\n", "line2\n", "line3\n"],
        )
        with patch("subprocess.Popen", return_value=proc):
            lines = list(stream_bash(Path("/fake/script.sh")))
        self.assertEqual(lines, ["line1", "line2", "line3"])

    def test_raises_on_non_zero_exit(self):
        proc = _make_proc_mock(returncode=1, stdout_lines=[])
        with patch("subprocess.Popen", return_value=proc):
            with self.assertRaises(subprocess.CalledProcessError):
                list(stream_bash(Path("/fake/script.sh")))

    def test_strips_trailing_newlines(self):
        proc = _make_proc_mock(returncode=0, stdout_lines=["  padded line  \n"])
        with patch("subprocess.Popen", return_value=proc):
            lines = list(stream_bash(Path("/fake/script.sh")))
        self.assertEqual(lines, ["  padded line"])

    def test_cancellation_raises_mid_stream(self):
        token = CancellationToken()
        yielded = []

        def generate_lines():
            for line in ["line1\n", "line2\n", "line3\n"]:
                token.set()  # cancel after first line
                yield line

        proc = _make_proc_mock(returncode=0)
        proc.stdout = generate_lines()
        with patch("subprocess.Popen", return_value=proc):
            with self.assertRaises(CancellationError):
                for line in stream_bash(Path("/fake/script.sh"), cancel_token=token):
                    yielded.append(line)


if __name__ == "__main__":
    unittest.main()
