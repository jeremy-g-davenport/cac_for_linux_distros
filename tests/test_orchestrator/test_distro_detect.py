"""tests/test_orchestrator/test_distro_detect.py — Unit tests for distros/detect.py"""
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from distros.arch.driver import ArchDriver
from distros.detect import OS_RELEASE_PATH, detect_distro


_CACHYOS_OS_RELEASE = """\
NAME=CachyOS
ID=cachyos
ID_LIKE=arch
PRETTY_NAME="CachyOS Linux"
"""

_ARCH_OS_RELEASE = """\
NAME="Arch Linux"
ID=arch
PRETTY_NAME="Arch Linux"
"""

_UBUNTU_OS_RELEASE = """\
NAME="Ubuntu"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 22.04"
"""

_UNKNOWN_OS_RELEASE = """\
NAME="FictionalOS"
ID=fictionalos
PRETTY_NAME="FictionalOS 1.0"
"""


def _patch_os_release(content):
    """Return a context manager that patches /etc/os-release content and machine arch."""
    os_release = patch.object(
        Path,
        "read_text",
        lambda self, *a, **kw: content if str(self) == str(OS_RELEASE_PATH) else Path.read_text.__wrapped__(self, *a, **kw),
    )
    machine = patch("distros.detect.platform.machine", return_value="x86_64")
    return os_release, machine


class TestDetectDistro(unittest.TestCase):
    def test_cachyos_returns_arch_driver(self):
        with patch.object(Path, "read_text", return_value=_CACHYOS_OS_RELEASE):
            with patch("distros.detect.platform.machine", return_value="x86_64"):
                info, driver = detect_distro()
        self.assertEqual(info.distro_id, "cachyos")
        self.assertIsInstance(driver, ArchDriver)

    def test_arch_linux_returns_arch_driver(self):
        with patch.object(Path, "read_text", return_value=_ARCH_OS_RELEASE):
            with patch("distros.detect.platform.machine", return_value="x86_64"):
                info, driver = detect_distro()
        self.assertEqual(info.distro_id, "arch")
        self.assertIsInstance(driver, ArchDriver)

    def test_ubuntu_raises_not_implemented_error(self):
        with patch.object(Path, "read_text", return_value=_UBUNTU_OS_RELEASE):
            with patch("distros.detect.platform.machine", return_value="x86_64"):
                with self.assertRaises(NotImplementedError):
                    detect_distro()

    def test_unknown_distro_raises_runtime_error(self):
        with patch.object(Path, "read_text", return_value=_UNKNOWN_OS_RELEASE):
            with patch("distros.detect.platform.machine", return_value="x86_64"):
                with self.assertRaises(RuntimeError):
                    detect_distro()

    def test_distro_info_arch_from_platform_machine(self):
        with patch.object(Path, "read_text", return_value=_CACHYOS_OS_RELEASE):
            with patch("distros.detect.platform.machine", return_value="aarch64"):
                info, _ = detect_distro()
        self.assertEqual(info.arch, "aarch64")

    def test_pretty_name_parsed_from_os_release(self):
        with patch.object(Path, "read_text", return_value=_CACHYOS_OS_RELEASE):
            with patch("distros.detect.platform.machine", return_value="x86_64"):
                info, _ = detect_distro()
        self.assertIn("CachyOS", info.pretty_name)

    def test_id_like_parsed_as_list(self):
        with patch.object(Path, "read_text", return_value=_CACHYOS_OS_RELEASE):
            with patch("distros.detect.platform.machine", return_value="x86_64"):
                info, _ = detect_distro()
        self.assertIn("arch", info.id_like)


if __name__ == "__main__":
    unittest.main()
