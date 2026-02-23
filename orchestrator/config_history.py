"""
config_history.py — In-session undo/redo stack for GUI config changes.

Per-session only: cleared on app restart. Every GUI config change is
also logged as an ActionRecord(action="config_change") to the persistent
action_log.json for cross-session audit.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass
class ConfigChange:
    key: str
    old_value: Any
    new_value: Any
    source: str = "gui"  # "gui" or "cli"


class ConfigHistory:
    def __init__(self) -> None:
        self._undo_stack: list[ConfigChange] = []
        self._redo_stack: list[ConfigChange] = []

    def record(self, change: ConfigChange) -> None:
        """Record a new config change and clear the redo stack."""
        self._undo_stack.append(change)
        self._redo_stack.clear()

    def undo(self) -> ConfigChange | None:
        """Pop the most recent change and push it to the redo stack."""
        if not self._undo_stack:
            return None
        change = self._undo_stack.pop()
        self._redo_stack.append(change)
        return change

    def redo(self) -> ConfigChange | None:
        """Re-apply the most recently undone change."""
        if not self._redo_stack:
            return None
        change = self._redo_stack.pop()
        self._undo_stack.append(change)
        return change

    def can_undo(self) -> bool:
        return bool(self._undo_stack)

    def can_redo(self) -> bool:
        return bool(self._redo_stack)

    def clear(self) -> None:
        self._undo_stack.clear()
        self._redo_stack.clear()
