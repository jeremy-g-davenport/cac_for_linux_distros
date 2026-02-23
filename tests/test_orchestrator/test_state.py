"""tests/test_orchestrator/test_state.py — Unit tests for orchestrator/state.py"""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from orchestrator.state import InstallState


class TestInstallState(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.state_dir = Path(self.tmpdir) / "var" / "lib" / "cac_for_linux_distros"
        self.state_file = self.state_dir / "state.json"

        # Patch STATE_DIR and STATE_FILE for all tests
        self.dir_patcher = patch("orchestrator.state.STATE_DIR", self.state_dir)
        self.file_patcher = patch("orchestrator.state.STATE_FILE", self.state_file)
        self.dir_patcher.start()
        self.file_patcher.start()

    def tearDown(self):
        self.file_patcher.stop()
        self.dir_patcher.stop()
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_round_trip_save_and_load(self):
        state = InstallState(
            distro_id="cachyos",
            arch="x86_64",
            real_user="testuser",
            packages_installed=["opensc=0.23.0", "pcsclite=1.9"],
            nss_databases=["/home/testuser/.pki/nssdb"],
        )
        state.save()
        loaded = InstallState.load()
        self.assertEqual(loaded.distro_id, "cachyos")
        self.assertEqual(loaded.arch, "x86_64")
        self.assertEqual(loaded.real_user, "testuser")
        self.assertEqual(loaded.packages_installed, ["opensc=0.23.0", "pcsclite=1.9"])
        self.assertEqual(loaded.nss_databases, ["/home/testuser/.pki/nssdb"])

    def test_save_creates_state_dir_if_missing(self):
        self.assertFalse(self.state_dir.exists())
        state = InstallState()
        state.save()
        self.assertTrue(self.state_dir.exists())
        self.assertTrue(self.state_file.exists())

    def test_load_raises_file_not_found_when_absent(self):
        with self.assertRaises(FileNotFoundError):
            InstallState.load()

    def test_save_is_atomic_via_tmp_file(self):
        """save() writes to .tmp then os.replace() — no partial writes visible."""
        state = InstallState(distro_id="cachyos")
        state.save()
        # The .tmp file should NOT exist after save() completes
        tmp_file = self.state_file.with_suffix(".json.tmp")
        self.assertFalse(tmp_file.exists())
        self.assertTrue(self.state_file.exists())

    def test_save_updates_last_updated_timestamp(self):
        state = InstallState()
        self.assertEqual(state.last_updated, 0.0)
        state.save()
        loaded = InstallState.load()
        self.assertGreater(loaded.last_updated, 0.0)

    def test_all_list_fields_default_to_empty_list(self):
        state = InstallState()
        self.assertEqual(state.packages_installed, [])
        self.assertEqual(state.nss_databases, [])
        self.assertEqual(state.imported_cert_nicknames, [])
        self.assertEqual(state.pkcs11_registered_in, [])

    def test_bool_field_preserved_through_round_trip(self):
        state = InstallState(pcscd_was_active_before=True)
        state.save()
        loaded = InstallState.load()
        self.assertTrue(loaded.pcscd_was_active_before)


if __name__ == "__main__":
    unittest.main()
