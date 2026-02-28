"""
driver.py — RedHatDriver: DistroDriver implementation for Red Hat family distros.

Covers Fedora, RHEL, CentOS Stream, Rocky Linux, and AlmaLinux.
All constants sourced from config.py; no magic strings inline.
"""
from __future__ import annotations

from ..base import DistroDriver, DistroInfo
from . import config


class RedHatDriver(DistroDriver):
    def __init__(self, info: DistroInfo) -> None:
        self.distro_info = info

    @property
    def package_manager(self) -> str:
        return "dnf"

    @property
    def required_packages(self) -> list[str]:
        return list(config.REQUIRED_PACKAGES)

    @property
    def smart_card_packages(self) -> list[str]:
        return list(config.SMART_CARD_PACKAGES)

    @property
    def pkcs11_lib_path(self) -> str:
        return config.PKCS11_LIB

    @property
    def pcscd_unit(self) -> str:
        return config.PCSCD_UNIT

    @property
    def firefox_profile_roots(self) -> list[str]:
        return list(config.FIREFOX_PROFILE_ROOTS)

    @property
    def opensc_conf_path(self) -> str:
        return config.OPENSC_CONF

    @property
    def has_aur(self) -> bool:
        return False

    def install_packages(self, packages: list[str]) -> list[str]:
        return ["dnf", "install", "-y", *packages]

    def remove_packages(self, packages: list[str]) -> list[str]:
        return ["dnf", "remove", "-y", *packages]

    def sync_package_db(self) -> list[str]:
        # dnf upgrade refreshes metadata and upgrades packages in one step.
        return ["dnf", "upgrade", "-y"]
