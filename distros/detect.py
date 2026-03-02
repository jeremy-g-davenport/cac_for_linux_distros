"""
detect.py — Distro detection via /etc/os-release.

Routes to the correct DistroDriver based on ID and ID_LIKE fields.
Returns (DistroInfo, DistroDriver) tuple.
"""
from __future__ import annotations

import platform
from pathlib import Path

from .base import DistroDriver, DistroInfo

OS_RELEASE_PATH = Path("/etc/os-release")

_ARCH_IDS = {"cachyos", "arch", "manjaro", "endeavouros", "garuda", "artix"}
_DEBIAN_IDS = {"ubuntu", "debian", "linuxmint", "pop", "elementary", "kali", "raspbian"}
_REDHAT_IDS = {"fedora", "rhel", "centos", "rocky", "almalinux"}


def detect_distro() -> tuple[DistroInfo, DistroDriver]:
    """
    Parse /etc/os-release and return the matching (DistroInfo, DistroDriver).

    Raises:
        RuntimeError: if the distro is not supported.
        NotImplementedError: if the distro is recognised but not yet implemented.
    """
    info = _parse_os_release()

    distro_id = info.distro_id.lower()
    id_like = {x.lower() for x in info.id_like}

    if distro_id in _ARCH_IDS or "arch" in id_like:
        from .arch.driver import ArchDriver
        return info, ArchDriver(info)

    if distro_id in _DEBIAN_IDS or "debian" in id_like or "ubuntu" in id_like:
        from .debian.driver import DebianDriver
        return info, DebianDriver(info)

    if distro_id in _REDHAT_IDS or "fedora" in id_like or "rhel" in id_like:
        from .redhat.driver import RedHatDriver
        return info, RedHatDriver(info)

    raise RuntimeError(
        f"Unsupported distribution: {info.pretty_name or distro_id!r}. "
        "Open an issue at https://github.com/<owner>/cac_for_linux_distros to request support."
    )


def _parse_os_release() -> DistroInfo:
    """Parse /etc/os-release into a DistroInfo dataclass."""
    fields: dict[str, str] = {}
    try:
        for line in OS_RELEASE_PATH.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            # Strip surrounding quotes
            val = val.strip().strip('"').strip("'")
            fields[key.strip()] = val
    except FileNotFoundError:
        pass  # fields will be empty → routing will raise RuntimeError

    distro_id = fields.get("ID", "")
    id_like_raw = fields.get("ID_LIKE", "")
    id_like = id_like_raw.split() if id_like_raw else []
    pretty_name = fields.get("PRETTY_NAME", distro_id)
    arch = platform.machine()

    return DistroInfo(
        distro_id=distro_id,
        id_like=id_like,
        arch=arch,
        pretty_name=pretty_name,
    )
