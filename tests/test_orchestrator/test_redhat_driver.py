"""tests/test_orchestrator/test_redhat_driver.py — Unit tests for RedHatDriver."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from distros.base import DistroInfo
from distros.redhat.driver import RedHatDriver


class TestRedHatDriver(unittest.TestCase):
    def setUp(self):
        self.info = DistroInfo(
            distro_id="fedora",
            id_like=[],
            arch="x86_64",
            pretty_name="Fedora Linux 40 (Workstation Edition)",
        )
        self.driver = RedHatDriver(self.info)

    def test_package_manager_is_dnf(self):
        self.assertEqual(self.driver.package_manager, "dnf")

    def test_pkcs11_lib_path_uses_lib64(self):
        self.assertIn("lib64", self.driver.pkcs11_lib_path)
        self.assertEqual(self.driver.pkcs11_lib_path, "/usr/lib64/opensc-pkcs11.so")

    def test_opensc_conf_path_is_flat(self):
        # Fedora opensc RPM ships /etc/opensc.conf, not /etc/opensc/opensc.conf
        self.assertEqual(self.driver.opensc_conf_path, "/etc/opensc.conf")
        self.assertNotIn("/opensc/", self.driver.opensc_conf_path)

    def test_has_aur_is_false(self):
        self.assertFalse(self.driver.has_aur)

    def test_pcscd_unit_is_socket(self):
        self.assertEqual(self.driver.pcscd_unit, "pcscd.socket")

    def test_required_packages_contains_nss_tools(self):
        # Fedora: nss-tools provides certutil/modutil (not 'nss' as on Arch)
        self.assertIn("nss-tools", self.driver.required_packages)
        self.assertNotIn("nss", self.driver.required_packages)

    def test_required_packages_contains_pcsc_lite_with_hyphen(self):
        # Fedora uses pcsc-lite (hyphen), not pcsclite (no hyphen) as on Arch
        self.assertIn("pcsc-lite", self.driver.required_packages)
        self.assertNotIn("pcsclite", self.driver.required_packages)

    def test_smart_card_packages_contains_pcsc_lite(self):
        self.assertIn("pcsc-lite", self.driver.smart_card_packages)
        self.assertNotIn("pcsclite", self.driver.smart_card_packages)

    def test_install_packages_uses_dnf(self):
        cmd = self.driver.install_packages(["opensc", "ccid"])
        self.assertEqual(cmd[0], "dnf")
        self.assertIn("install", cmd)
        self.assertIn("opensc", cmd)
        self.assertIn("ccid", cmd)

    def test_install_packages_empty_list_is_valid_prefix(self):
        # install_packages([]) must return a valid command prefix (no trailing args)
        cmd = self.driver.install_packages([])
        self.assertEqual(cmd, ["dnf", "install", "-y"])

    def test_remove_packages_uses_dnf(self):
        cmd = self.driver.remove_packages(["opensc"])
        self.assertEqual(cmd[0], "dnf")
        self.assertIn("remove", cmd)
        self.assertIn("opensc", cmd)

    def test_sync_package_db_uses_dnf_upgrade(self):
        cmd = self.driver.sync_package_db()
        self.assertIn("dnf", cmd)
        self.assertIn("upgrade", cmd)

    def test_firefox_profile_root_is_standard_mozilla_path(self):
        roots = self.driver.firefox_profile_roots
        self.assertIn(".mozilla/firefox", roots)
        # Fedora does NOT have the CachyOS variant
        self.assertNotIn(".config/mozilla/firefox", roots)

    def test_required_packages_returns_new_list_each_call(self):
        # Must return a copy, not the internal list (mutation safety)
        pkgs1 = self.driver.required_packages
        pkgs1.append("__sentinel__")
        pkgs2 = self.driver.required_packages
        self.assertNotIn("__sentinel__", pkgs2)


if __name__ == "__main__":
    unittest.main()
