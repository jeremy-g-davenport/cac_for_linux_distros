"""tests/test_orchestrator/test_setup_flow.py — Unit tests for orchestrator/setup_flow.py"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from orchestrator.setup_flow import _apply_state, _build_env
from orchestrator.state import InstallState


class TestApplyStateAppend(unittest.TestCase):
    """Bug 2: += STATE lines must accumulate list items, not be silently dropped."""

    def _fresh_state(self):
        return InstallState(real_user="testuser")

    def test_imported_cert_nicknames_plus_appends(self):
        state = self._fresh_state()
        _apply_state("imported_cert_nicknames+", "DoD_Root_CA_1.cer", state)
        _apply_state("imported_cert_nicknames+", "DoD_Root_CA_2.cer", state)
        self.assertEqual(
            state.imported_cert_nicknames,
            ["DoD_Root_CA_1.cer", "DoD_Root_CA_2.cer"],
        )

    def test_imported_cert_nicknames_plus_ignores_empty_val(self):
        state = self._fresh_state()
        _apply_state("imported_cert_nicknames+", "", state)
        self.assertEqual(state.imported_cert_nicknames, [])

    def test_pkcs11_registered_in_plus_appends(self):
        state = self._fresh_state()
        _apply_state("pkcs11_registered_in+", "/home/user/.pki/nssdb", state)
        _apply_state("pkcs11_registered_in+", "/home/user/.config/mozilla/firefox/abc", state)
        self.assertEqual(
            state.pkcs11_registered_in,
            ["/home/user/.pki/nssdb", "/home/user/.config/mozilla/firefox/abc"],
        )

    def test_pkcs11_registered_in_plus_ignores_empty_val(self):
        state = self._fresh_state()
        _apply_state("pkcs11_registered_in+", "", state)
        self.assertEqual(state.pkcs11_registered_in, [])

    def test_imported_cert_nicknames_bulk_replace_still_works(self):
        """The non-+ variant (bulk replace) must still function."""
        state = self._fresh_state()
        _apply_state("imported_cert_nicknames+", "old.cer", state)
        _apply_state("imported_cert_nicknames", "new1.cer,new2.cer", state)
        self.assertEqual(state.imported_cert_nicknames, ["new1.cer", "new2.cer"])


class TestBuildEnvNssDbPaths(unittest.TestCase):
    """Bug 3: _build_env must include NSS_DB_PATHS when state.nss_databases is set."""

    class _FakeDriver:
        pkcs11_lib_path = "/usr/lib/opensc-pkcs11.so"
        pcscd_unit = "pcscd.socket"
        opensc_conf_path = "/etc/opensc/opensc.conf"
        has_aur = True
        package_manager = "pacman"
        required_packages = ["pcsclite", "opensc"]
        smart_card_packages = ["pcsclite", "opensc"]

        class distro_info:
            distro_id = "cachyos"
            arch = "x86_64"

        def install_packages(self, packages):
            return ["pacman", "-S", "--needed", "--noconfirm", *packages]

        def remove_packages(self, packages):
            return ["pacman", "-Rns", "--noconfirm", *packages]

        def sync_package_db(self):
            return ["pacman", "-Syu", "--noconfirm"]

    def test_nss_db_paths_included_when_state_has_databases(self):
        state = InstallState(
            real_user="testuser",
            nss_databases=["/home/user/.pki/nssdb", "/home/user/.config/mozilla/firefox/abc"],
        )
        env = _build_env(self._FakeDriver(), "testuser", state)
        self.assertIn("NSS_DB_PATHS", env)
        self.assertEqual(env["NSS_DB_PATHS"], "/home/user/.pki/nssdb:/home/user/.config/mozilla/firefox/abc")

    def test_nss_db_paths_absent_when_state_has_no_databases(self):
        state = InstallState(real_user="testuser")
        env = _build_env(self._FakeDriver(), "testuser", state)
        self.assertNotIn("NSS_DB_PATHS", env)

    def test_env_rebuilt_per_phase_reflects_updated_nss_databases(self):
        """Rebuilding env after state update picks up newly discovered databases."""
        state = InstallState(real_user="testuser")
        env_before = _build_env(self._FakeDriver(), "testuser", state)
        self.assertNotIn("NSS_DB_PATHS", env_before)

        # Simulate import phase emitting STATE:nss_databases
        _apply_state("nss_databases", "/home/user/.pki/nssdb:/home/user/.config/mozilla/firefox/abc", state)

        env_after = _build_env(self._FakeDriver(), "testuser", state)
        self.assertIn("NSS_DB_PATHS", env_after)
        self.assertEqual(env_after["NSS_DB_PATHS"], "/home/user/.pki/nssdb:/home/user/.config/mozilla/firefox/abc")


if __name__ == "__main__":
    unittest.main()
