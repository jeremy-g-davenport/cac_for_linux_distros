"""tests/test_orchestrator/test_action_log.py — Unit tests for orchestrator/action_log.py"""
import json
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from orchestrator.action_log import (
    ACTION_LOG_FILE,
    ActionRecord,
    append_action,
    load_log,
    make_record,
    mark_reversed,
)


class TestActionLog(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.state_dir = Path(self.tmpdir) / "var" / "lib" / "cac_for_linux_distros"
        self.log_file = self.state_dir / "action_log.json"

        self.dir_patcher = patch("orchestrator.action_log.STATE_DIR", self.state_dir)
        self.file_patcher = patch("orchestrator.action_log.ACTION_LOG_FILE", self.log_file)
        self.dir_patcher.start()
        self.file_patcher.start()

    def tearDown(self):
        self.file_patcher.stop()
        self.dir_patcher.stop()
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_load_log_returns_empty_list_when_absent(self):
        self.assertEqual(load_log(), [])

    def test_append_action_writes_to_file(self):
        rec = make_record("cert_import", "/home/user/.pki/nssdb", nickname="TestCA")
        append_action(rec)
        self.assertTrue(self.log_file.exists())
        records = load_log()
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0].action, "cert_import")

    def test_load_log_round_trips_all_fields(self):
        rec = ActionRecord(
            timestamp=1000.0,
            action="pkcs11_register",
            target="/home/user/.pki/nssdb",
            detail={"module": "CAC Module"},
            reversed=False,
        )
        append_action(rec)
        loaded = load_log()
        self.assertEqual(loaded[0].timestamp, 1000.0)
        self.assertEqual(loaded[0].action, "pkcs11_register")
        self.assertEqual(loaded[0].detail, {"module": "CAC Module"})
        self.assertFalse(loaded[0].reversed)

    def test_mark_reversed_sets_reversed_flag(self):
        rec = make_record("cert_import", "/home/user/.pki/nssdb")
        append_action(rec)
        mark_reversed(rec.timestamp)
        records = load_log()
        self.assertTrue(records[0].reversed)

    def test_append_multiple_records(self):
        for i in range(3):
            append_action(make_record(f"action_{i}", f"/path/{i}"))
        records = load_log()
        self.assertEqual(len(records), 3)
        self.assertEqual(records[0].action, "action_0")
        self.assertEqual(records[2].action, "action_2")

    def test_make_record_sets_timestamp_automatically(self):
        before = time.time()
        rec = make_record("test_action", "/target")
        after = time.time()
        self.assertGreaterEqual(rec.timestamp, before)
        self.assertLessEqual(rec.timestamp, after)

    def test_write_is_atomic_no_tmp_file_remains(self):
        rec = make_record("test", "/t")
        append_action(rec)
        tmp = self.log_file.with_suffix(".json.tmp")
        self.assertFalse(tmp.exists())
        self.assertTrue(self.log_file.exists())


if __name__ == "__main__":
    unittest.main()
