"""
driver.py — ArchDriver: DistroDriver implementation for Arch-based distros.

Covers CachyOS, Arch Linux, Manjaro, EndeavourOS, Garuda, and Artix.
All constants sourced from config.py; no magic strings inline.
"""
from __future__ import annotations

from ..base import DistroDriver, DistroInfo
from . import config


class ArchDriver(DistroDriver):
    def __init__(self, info: DistroInfo) -> None:
        self.distro_info = info

    @property
    def package_manager(self) -> str:
        return "pacman"

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

    def install_packages(self, packages: list[str]) -> list[str]:
        return ["pacman", "-S", "--needed", "--noconfirm", *packages]

    def remove_packages(self, packages: list[str]) -> list[str]:
        return ["pacman", "-Rns", "--noconfirm", *packages]

    def sync_package_db(self) -> list[str]:
        # Always full sync + upgrade — never -Sy alone (partial upgrade breaks rolling release)
        return ["pacman", "-Syu", "--noconfirm"]
