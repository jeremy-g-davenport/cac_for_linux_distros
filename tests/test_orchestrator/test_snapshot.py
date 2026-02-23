"""tests/test_orchestrator/test_snapshot.py — Unit tests for orchestrator/snapshot.py"""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from orchestrator.snapshot import (
    NSSSnapshot,
    Snapshot,
    _read_certs,
    _read_modules,
    create_snapshot,
    list_all,
)


class TestSnapshotRoundTrip(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.snap_dir = Path(self.tmpdir) / "20260101_120000"

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_save_creates_snapshot_json(self):
        snap = Snapshot(
            label="pre-update",
            timestamp="2026-01-01T12:00:00",
            app_version="0.1.0",
        )
        snap.save(self.snap_dir)
        self.assertTrue((self.snap_dir / "snapshot.json").exists())

    def test_round_trip_preserves_all_fields(self):
        nss = NSSSnapshot(
            db_path="/home/user/.pki/nssdb",
            certs=[{"nickname": "DoD Root CA", "trust_flags": "CT,,"}],
            modules=[{"name": "CAC Module", "lib_path": "/usr/lib/opensc-pkcs11.so"}],
        )
        snap = Snapshot(
            label="pre-update",
            timestamp="2026-01-01T12:00:00",
            app_version="0.1.0",
            nss=[nss],
        )
        snap.save(self.snap_dir)
        loaded = Snapshot.load(self.snap_dir)

        self.assertEqual(loaded.label, "pre-update")
        self.assertEqual(loaded.timestamp, "2026-01-01T12:00:00")
        self.assertEqual(loaded.app_version, "0.1.0")
        self.assertEqual(len(loaded.nss), 1)
        self.assertEqual(loaded.nss[0].db_path, "/home/user/.pki/nssdb")
        self.assertEqual(loaded.nss[0].certs[0]["nickname"], "DoD Root CA")
        self.assertEqual(loaded.nss[0].modules[0]["name"], "CAC Module")

    def test_save_with_empty_nss_list(self):
        snap = Snapshot(
            label="empty",
            timestamp="2026-01-01T00:00:00",
            app_version="0.1.0",
        )
        snap.save(self.snap_dir)
        loaded = Snapshot.load(self.snap_dir)
        self.assertEqual(loaded.nss, [])

    def test_save_is_valid_json(self):
        snap = Snapshot(
            label="test",
            timestamp="2026-01-01T00:00:00",
            app_version="0.1.0",
        )
        snap.save(self.snap_dir)
        raw = (self.snap_dir / "snapshot.json").read_text()
        parsed = json.loads(raw)
        self.assertIn("label", parsed)
        self.assertIn("timestamp", parsed)
        self.assertIn("nss", parsed)


class TestListAll(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.snapshots_dir = Path(self.tmpdir) / "snapshots"

        self.snapshots_dir_patcher = patch(
            "orchestrator.snapshot.SNAPSHOTS_DIR", self.snapshots_dir
        )
        self.snapshots_dir_patcher.start()

    def tearDown(self):
        self.snapshots_dir_patcher.stop()
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_list_all_returns_empty_when_no_snapshots_dir(self):
        self.assertEqual(list_all(), [])

    def test_list_all_returns_sorted_newest_first(self):
        for name in ("20260101_090000", "20260103_090000", "20260102_090000"):
            d = self.snapshots_dir / name
            d.mkdir(parents=True)
            (d / "snapshot.json").write_text("{}")

        result = list_all()
        names = [d.name for d in result]
        self.assertEqual(names, ["20260103_090000", "20260102_090000", "20260101_090000"])

    def test_list_all_ignores_dirs_without_snapshot_json(self):
        (self.snapshots_dir / "20260101_090000").mkdir(parents=True)
        d = self.snapshots_dir / "20260102_090000"
        d.mkdir(parents=True)
        (d / "snapshot.json").write_text("{}")

        result = list_all()
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0].name, "20260102_090000")


class TestReadCerts(unittest.TestCase):
    def test_parses_certutil_output(self):
        fake_output = (
            "Certificate Nickname                                         Trust Attributes\n"
            "                                                             SSL,S/MIME,JAR/XPI\n"
            "\n"
            "DoD Root CA 3                                                CT,,\n"
            "DoD Root CA 4                                                CT,,\n"
        )
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(stdout=fake_output, returncode=0)
            certs = _read_certs("/home/user/.pki/nssdb")

        self.assertEqual(len(certs), 2)
        self.assertEqual(certs[0]["nickname"], "DoD Root CA 3")
        self.assertEqual(certs[0]["trust_flags"], "CT,,")
        self.assertEqual(certs[1]["nickname"], "DoD Root CA 4")

    def test_returns_empty_list_when_certutil_not_found(self):
        with patch("subprocess.run", side_effect=FileNotFoundError):
            certs = _read_certs("/home/user/.pki/nssdb")
        self.assertEqual(certs, [])

    def test_skips_header_and_blank_lines(self):
        fake_output = "Certificate Nickname       Trust Attributes\n\n---\n\nMyCA  CT,,\n"
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(stdout=fake_output, returncode=0)
            certs = _read_certs("/tmp/db")
        self.assertEqual(len(certs), 1)
        self.assertEqual(certs[0]["nickname"], "MyCA")


class TestReadModules(unittest.TestCase):
    def test_parses_modutil_output(self):
        fake_output = (
            "Listing of PKCS #11 Modules\n"
            "-----------------------------------------------------------\n"
            "  1. NSS Internal PKCS #11 Module\n"
            "          (this module is internally loaded)\n"
            "  2. CAC Module\n"
            "     Name: CAC Module\n"
            "     Library file: /usr/lib/opensc-pkcs11.so\n"
        )
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(stdout=fake_output, returncode=0)
            modules = _read_modules("/home/user/.pki/nssdb")

        self.assertEqual(len(modules), 1)
        self.assertEqual(modules[0]["name"], "CAC Module")
        self.assertEqual(modules[0]["lib_path"], "/usr/lib/opensc-pkcs11.so")

    def test_returns_empty_list_when_modutil_not_found(self):
        with patch("subprocess.run", side_effect=FileNotFoundError):
            modules = _read_modules("/home/user/.pki/nssdb")
        self.assertEqual(modules, [])


class TestCreateSnapshot(unittest.TestCase):
    def test_create_snapshot_calls_read_helpers(self):
        fake_state = MagicMock()
        fake_state.nss_databases = ["/home/user/.pki/nssdb"]

        with patch("orchestrator.snapshot._read_certs", return_value=[]) as mock_certs, \
             patch("orchestrator.snapshot._read_modules", return_value=[]) as mock_modules, \
             patch("orchestrator.snapshot.datetime") as mock_dt, \
             patch("builtins.__import__", side_effect=lambda name, *a, **kw: (
                 type("M", (), {"__version__": "0.1.0"})() if name == "version" else __import__(name, *a, **kw)
             )):
            mock_dt.utcnow.return_value.isoformat.return_value = "2026-01-01T00:00:00"

            snap = create_snapshot(fake_state, label="test-snap")

        mock_certs.assert_called_once_with("/home/user/.pki/nssdb")
        mock_modules.assert_called_once_with("/home/user/.pki/nssdb")
        self.assertEqual(snap.label, "test-snap")
        self.assertEqual(len(snap.nss), 1)
        self.assertEqual(snap.nss[0].db_path, "/home/user/.pki/nssdb")


if __name__ == "__main__":
    unittest.main()
