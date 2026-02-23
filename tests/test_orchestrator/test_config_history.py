"""tests/test_orchestrator/test_config_history.py — Unit tests for orchestrator/config_history.py"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from orchestrator.config_history import ConfigChange, ConfigHistory


class TestConfigHistory(unittest.TestCase):
    def setUp(self):
        self.history = ConfigHistory()

    def test_new_history_cannot_undo_or_redo(self):
        self.assertFalse(self.history.can_undo())
        self.assertFalse(self.history.can_redo())

    def test_record_enables_undo(self):
        self.history.record(ConfigChange(key="theme", old_value="light", new_value="dark"))
        self.assertTrue(self.history.can_undo())

    def test_undo_returns_change_and_enables_redo(self):
        change = ConfigChange(key="theme", old_value="light", new_value="dark")
        self.history.record(change)

        result = self.history.undo()

        self.assertIs(result, change)
        self.assertFalse(self.history.can_undo())
        self.assertTrue(self.history.can_redo())

    def test_redo_returns_change_and_re_enables_undo(self):
        change = ConfigChange(key="theme", old_value="light", new_value="dark")
        self.history.record(change)
        self.history.undo()

        result = self.history.redo()

        self.assertIs(result, change)
        self.assertTrue(self.history.can_undo())
        self.assertFalse(self.history.can_redo())

    def test_undo_on_empty_stack_returns_none(self):
        self.assertIsNone(self.history.undo())

    def test_redo_on_empty_stack_returns_none(self):
        self.assertIsNone(self.history.redo())

    def test_new_record_clears_redo_stack(self):
        self.history.record(ConfigChange(key="a", old_value=1, new_value=2))
        self.history.undo()
        self.assertTrue(self.history.can_redo())

        self.history.record(ConfigChange(key="b", old_value=3, new_value=4))
        self.assertFalse(self.history.can_redo())

    def test_multiple_undos_restore_lifo_order(self):
        c1 = ConfigChange(key="x", old_value=0, new_value=1)
        c2 = ConfigChange(key="y", old_value=0, new_value=2)
        self.history.record(c1)
        self.history.record(c2)

        self.assertIs(self.history.undo(), c2)
        self.assertIs(self.history.undo(), c1)
        self.assertFalse(self.history.can_undo())

    def test_clear_empties_both_stacks(self):
        self.history.record(ConfigChange(key="a", old_value=1, new_value=2))
        self.history.undo()
        self.assertTrue(self.history.can_redo())

        self.history.clear()

        self.assertFalse(self.history.can_undo())
        self.assertFalse(self.history.can_redo())

    def test_config_change_source_defaults_to_gui(self):
        change = ConfigChange(key="font", old_value="mono", new_value="sans")
        self.assertEqual(change.source, "gui")

    def test_config_change_accepts_cli_source(self):
        change = ConfigChange(key="font", old_value="mono", new_value="sans", source="cli")
        self.assertEqual(change.source, "cli")


if __name__ == "__main__":
    unittest.main()
