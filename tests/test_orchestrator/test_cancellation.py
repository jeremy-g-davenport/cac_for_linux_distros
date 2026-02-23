"""tests/test_orchestrator/test_cancellation.py — Unit tests for orchestrator/cancellation.py"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from orchestrator.cancellation import CancellationError, CancellationToken


class TestCancellationToken(unittest.TestCase):
    def test_starts_unset(self):
        token = CancellationToken()
        self.assertFalse(token.is_set())

    def test_set_makes_is_set_true(self):
        token = CancellationToken()
        token.set()
        self.assertTrue(token.is_set())

    def test_check_raises_when_set(self):
        token = CancellationToken()
        token.set()
        with self.assertRaises(CancellationError):
            token.check()

    def test_check_is_noop_when_unset(self):
        token = CancellationToken()
        # Should not raise
        token.check()

    def test_set_is_idempotent(self):
        token = CancellationToken()
        token.set()
        token.set()
        self.assertTrue(token.is_set())

    def test_cancellation_error_is_exception(self):
        self.assertTrue(issubclass(CancellationError, Exception))


if __name__ == "__main__":
    unittest.main()
