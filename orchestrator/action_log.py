"""
action_log.py — Append-only audit trail of every atomic install action.

Each ActionRecord maps 1:1 to an [ACTION] line in the log file and
to one atomic operation that the uninstall flow may need to reverse.
Writes are atomic: full updated file written to .tmp then os.replace().
"""
from __future__ import annotations

import json
import os
import time
from dataclasses import asdict, dataclass, field
from typing import Any

from .state import STATE_DIR

ACTION_LOG_FILE = STATE_DIR / "action_log.json"


@dataclass
class ActionRecord:
    timestamp: float
    action: str
    target: str
    detail: dict[str, Any] = field(default_factory=dict)
    reversed: bool = False


def append_action(record: ActionRecord) -> None:
    """Append an ActionRecord to the log file atomically."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    records = load_log()
    records.append(record)
    _write_log(records)


def load_log() -> list[ActionRecord]:
    """Return all ActionRecords from the log file, or [] if none."""
    if not ACTION_LOG_FILE.exists():
        return []
    raw = json.loads(ACTION_LOG_FILE.read_text())
    return [ActionRecord(**r) for r in raw]


def mark_reversed(timestamp: float) -> None:
    """Set reversed=True on the record with the given timestamp."""
    records = load_log()
    for rec in records:
        if rec.timestamp == timestamp:
            rec.reversed = True
    _write_log(records)


def _write_log(records: list[ActionRecord]) -> None:
    tmp = ACTION_LOG_FILE.with_suffix(".json.tmp")
    data = [asdict(r) for r in records]
    with open(tmp, "w") as fh:
        fh.write(json.dumps(data, indent=2))
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, ACTION_LOG_FILE)


def make_record(action: str, target: str, **detail: Any) -> ActionRecord:
    """Convenience factory — timestamps automatically."""
    return ActionRecord(
        timestamp=time.time(),
        action=action,
        target=target,
        detail=detail,
    )
