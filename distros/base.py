"""
base.py — DistroDriver abstract base class and DistroInfo dataclass.

Adding a new distro:
1. Create distros/<name>/ directory
2. Create distros/<name>/config.py with distro-specific constants
3. Create distros/<name>/driver.py implementing DistroDriver
4. Add one routing branch in distros/detect.py
5. No orchestrator, lib/, or bash/ changes required.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class DistroInfo:
    distro_id: str
    id_like: list[str] = field(default_factory=list)
    arch: str = ""
    pretty_name: str = ""


class DistroDriver(ABC):
    """Abstract base class for all distro-specific drivers."""

    @property
    @abstractmethod
    def package_manager(self) -> str:
        """Binary name of the package manager, e.g. 'pacman'."""

    @property
    @abstractmethod
    def required_packages(self) -> list[str]:
        """All packages required for CAC setup."""

    @property
    @abstractmethod
    def smart_card_packages(self) -> list[str]:
        """Subset of required_packages offered for removal on uninstall."""

    @property
    @abstractmethod
    def pkcs11_lib_path(self) -> str:
        """Absolute path to opensc-pkcs11.so."""

    @property
    @abstractmethod
    def pcscd_unit(self) -> str:
        """Systemd unit name for the smart card daemon, e.g. 'pcscd.socket'."""

    @property
    @abstractmethod
    def firefox_profile_roots(self) -> list[str]:
        """Candidate paths relative to $HOME, in preference order."""

    @abstractmethod
    def install_packages(self, packages: list[str]) -> list[str]:
        """Return shell command tokens to install the given packages."""

    @abstractmethod
    def remove_packages(self, packages: list[str]) -> list[str]:
        """Return shell command tokens to remove the given packages."""

    @abstractmethod
    def sync_package_db(self) -> list[str]:
        """Return shell command tokens to sync the package database."""
