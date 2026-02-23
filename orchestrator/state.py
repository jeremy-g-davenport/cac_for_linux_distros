"""
state.py — InstallState dataclass with atomic JSON persistence.

STATE_FILE is written incrementally after each phase. If install fails
partway through, the uninstall flow reads this file and reverses only
what was actually completed.
"""
from __future__ import annotations

import json
import os
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path

STATE_DIR = Path("/var/lib/cac_for_linux_distros")
STATE_FILE = STATE_DIR / "state.json"


@dataclass
class InstallState:
    version: str = "1"
    distro_id: str = ""
    arch: str = ""
    real_user: str = ""
    install_timestamp: float = 0.0
    last_updated: float = 0.0
    packages_installed: list[str] = field(default_factory=list)
    pcscd_was_active_before: bool = False
    cert_bundle_sha256: str = ""
    nss_databases: list[str] = field(default_factory=list)
    imported_cert_nicknames: list[str] = field(default_factory=list)
    pkcs11_registered_in: list[str] = field(default_factory=list)

    def save(self) -> None:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        self.last_updated = time.time()
        tmp = STATE_FILE.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(asdict(self), indent=2))
        os.replace(tmp, STATE_FILE)  # atomic on POSIX

    @classmethod
    def load(cls) -> "InstallState":
        if not STATE_FILE.exists():
            raise FileNotFoundError(f"State file not found: {STATE_FILE}")
        return cls(**json.loads(STATE_FILE.read_text()))
