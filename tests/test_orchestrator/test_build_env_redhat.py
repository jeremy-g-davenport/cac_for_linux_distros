"""tests/test_orchestrator/test_build_env_redhat.py — Tests for _build_env() with RedHatDriver."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from distros.base import DistroInfo
from distros.redhat.driver import RedHatDriver
from orchestrator.setup_flow import _build_env
from orchestrator.state import InstallState


class TestBuildEnvRedHat(unittest.TestCase):
    def setUp(self):
        info = DistroInfo(distro_id="fedora", arch="x86_64")
        self.driver = RedHatDriver(info)
        self.state = InstallState(real_user="testuser")

    def test_opensc_conf_injected_as_flat_path(self):
        env = _build_env(self.driver, "testuser", self.state)
        self.assertEqual(env["OPENSC_CONF"], "/etc/opensc.conf")

    def test_has_aur_is_zero_for_red_hat(self):
        env = _build_env(self.driver, "testuser", self.state)
        self.assertEqual(env["HAS_AUR"], "0")

    def test_pkg_query_cmd_uses_rpm(self):
        env = _build_env(self.driver, "testuser", self.state)
        self.assertIn("rpm", env["PKG_QUERY_CMD"])

    def test_pkg_sync_cmd_uses_dnf_upgrade(self):
        env = _build_env(self.driver, "testuser", self.state)
        self.assertIn("dnf", env["PKG_SYNC_CMD"])
        self.assertIn("upgrade", env["PKG_SYNC_CMD"])

    def test_pkg_install_prefix_uses_dnf_install(self):
        env = _build_env(self.driver, "testuser", self.state)
        self.assertIn("dnf", env["PKG_INSTALL_PREFIX"])
        self.assertIn("install", env["PKG_INSTALL_PREFIX"])

    def test_pkg_remove_prefix_uses_dnf_remove(self):
        env = _build_env(self.driver, "testuser", self.state)
        self.assertIn("dnf", env["PKG_REMOVE_PREFIX"])
        self.assertIn("remove", env["PKG_REMOVE_PREFIX"])

    def test_required_packages_env_contains_nss_tools(self):
        env = _build_env(self.driver, "testuser", self.state)
        self.assertIn("nss-tools", env["REQUIRED_PACKAGES_ENV"])

    def test_required_packages_env_contains_pcsc_lite(self):
        env = _build_env(self.driver, "testuser", self.state)
        self.assertIn("pcsc-lite", env["REQUIRED_PACKAGES_ENV"])

    def test_smart_card_packages_env_set(self):
        env = _build_env(self.driver, "testuser", self.state)
        self.assertIn("SMART_CARD_PACKAGES_ENV", env)
        self.assertIn("pcsc-lite", env["SMART_CARD_PACKAGES_ENV"])

    def test_pkcs11_lib_injected(self):
        env = _build_env(self.driver, "testuser", self.state)
        self.assertEqual(env["PKCS11_LIB"], "/usr/lib64/opensc-pkcs11.so")


class TestBuildEnvArch(unittest.TestCase):
    """Regression: existing Arch env vars still injected correctly after refactor."""

    class _ArchFakeDriver:
        pkcs11_lib_path = "/usr/lib/opensc-pkcs11.so"
        pcscd_unit = "pcscd.socket"
        opensc_conf_path = "/etc/opensc/opensc.conf"
        has_aur = True
        package_manager = "pacman"
        required_packages = ["pcsclite", "opensc"]
        smart_card_packages = ["pcsclite", "opensc"]

        def install_packages(self, packages):
            return ["pacman", "-S", "--needed", "--noconfirm", *packages]

        def remove_packages(self, packages):
            return ["pacman", "-Rns", "--noconfirm", *packages]

        def sync_package_db(self):
            return ["pacman", "-Syu", "--noconfirm"]

    def test_arch_has_aur_is_one(self):
        state = InstallState(real_user="testuser")
        env = _build_env(self._ArchFakeDriver(), "testuser", state)
        self.assertEqual(env["HAS_AUR"], "1")

    def test_arch_opensc_conf_uses_subdirectory(self):
        state = InstallState(real_user="testuser")
        env = _build_env(self._ArchFakeDriver(), "testuser", state)
        self.assertEqual(env["OPENSC_CONF"], "/etc/opensc/opensc.conf")

    def test_arch_pkg_query_cmd_uses_pacman(self):
        state = InstallState(real_user="testuser")
        env = _build_env(self._ArchFakeDriver(), "testuser", state)
        self.assertIn("pacman", env["PKG_QUERY_CMD"])

    def test_arch_pkg_sync_cmd_uses_syu(self):
        state = InstallState(real_user="testuser")
        env = _build_env(self._ArchFakeDriver(), "testuser", state)
        self.assertIn("-Syu", env["PKG_SYNC_CMD"])


if __name__ == "__main__":
    unittest.main()
