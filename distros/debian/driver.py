"""
driver.py — DebianDriver stub.

Debian/Ubuntu support is not yet implemented. The class exists so that
the routing in distros/detect.py compiles on any system. When Debian
support is added, implement each abstract method using apt conventions.
"""
from __future__ import annotations

from ..base import DistroDriver, DistroInfo


class DebianDriver(DistroDriver):
    def __init__(self, info: DistroInfo) -> None:
        raise NotImplementedError(
            "Debian/Ubuntu support is not yet implemented. "
            "See https://github.com/<owner>/cac_for_linux_distros for roadmap."
        )

    @property
    def package_manager(self) -> str:
        raise NotImplementedError

    @property
    def required_packages(self) -> list[str]:
        raise NotImplementedError

    @property
    def smart_card_packages(self) -> list[str]:
        raise NotImplementedError

    @property
    def pkcs11_lib_path(self) -> str:
        raise NotImplementedError

    @property
    def pcscd_unit(self) -> str:
        raise NotImplementedError

    @property
    def firefox_profile_roots(self) -> list[str]:
        raise NotImplementedError

    def install_packages(self, packages: list[str]) -> list[str]:
        raise NotImplementedError

    def remove_packages(self, packages: list[str]) -> list[str]:
        raise NotImplementedError

    def sync_package_db(self) -> list[str]:
        raise NotImplementedError
