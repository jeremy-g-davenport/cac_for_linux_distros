"""
snapshot.py — Config-only snapshots of NSS certificate and PKCS11 state.

A snapshot captures only what the application owns: certificates imported
into each NSS database and PKCS11 registrations. It never touches packages
or services, so other processes are unaffected by a restore.

Storage: /var/lib/cac_for_linux_distros/snapshots/<YYYYMMDD_HHMMSS>/snapshot.json
"""
from __future__ import annotations

import json
import subprocess
from dataclasses import asdict, dataclass, field
from datetime import datetime
from pathlib import Path

from .state import STATE_DIR

SNAPSHOTS_DIR = STATE_DIR / "snapshots"


@dataclass
class NSSSnapshot:
    db_path: str
    certs: list[dict]    # [{"nickname": ..., "trust_flags": ...}]
    modules: list[dict]  # [{"name": ..., "lib_path": ...}]


@dataclass
class Snapshot:
    label: str
    timestamp: str           # ISO-8601
    app_version: str
    nss: list[NSSSnapshot] = field(default_factory=list)

    def save(self, snap_dir: Path) -> None:
        snap_dir.mkdir(parents=True, exist_ok=True)
        snap_file = snap_dir / "snapshot.json"
        snap_file.write_text(json.dumps(asdict(self), indent=2))

    @classmethod
    def load(cls, snap_dir: Path) -> "Snapshot":
        data = json.loads((snap_dir / "snapshot.json").read_text())
        nss = [NSSSnapshot(**n) for n in data.pop("nss", [])]
        snap = cls(**data)
        snap.nss = nss
        return snap


def create_snapshot(state, label: str) -> Snapshot:
    """
    Read current NSS state directly from databases (not just state.json)
    to catch any drift. Returns a Snapshot; caller must call .save().
    """
    from version import __version__

    nss_snapshots = []
    for db_path in state.nss_databases:
        certs = _read_certs(db_path)
        modules = _read_modules(db_path)
        nss_snapshots.append(NSSSnapshot(db_path=db_path, certs=certs, modules=modules))

    return Snapshot(
        label=label,
        timestamp=datetime.utcnow().isoformat(),
        app_version=__version__,
        nss=nss_snapshots,
    )


def list_all() -> list[Path]:
    """Return snapshot directories sorted newest-first."""
    if not SNAPSHOTS_DIR.exists():
        return []
    dirs = [d for d in SNAPSHOTS_DIR.iterdir() if d.is_dir() and (d / "snapshot.json").exists()]
    return sorted(dirs, reverse=True)


def _read_certs(db_path: str) -> list[dict]:
    """Parse `certutil -L -d sql:<db_path>` output into cert dicts."""
    try:
        result = subprocess.run(
            ["certutil", "-L", "-d", f"sql:{db_path}"],
            capture_output=True,
            text=True,
        )
        certs = []
        for line in result.stdout.splitlines():
            # Skip header lines (blank, or containing "Certificate Nickname" / dashes)
            stripped = line.strip()
            if not stripped or stripped.startswith("Certificate Nickname") or set(stripped) == {"-"}:
                continue
            # Format: "<nickname>  <trust_flags>"
            parts = stripped.rsplit(None, 1)
            if len(parts) == 2:
                certs.append({"nickname": parts[0].strip(), "trust_flags": parts[1].strip()})
        return certs
    except FileNotFoundError:
        return []


def _read_modules(db_path: str) -> list[dict]:
    """Parse `modutil -dbdir sql:<db_path> -list` output into module dicts."""
    try:
        result = subprocess.run(
            ["modutil", "-dbdir", f"sql:{db_path}", "-list"],
            capture_output=True,
            text=True,
            input="\n",  # modutil may prompt; send newline to auto-dismiss
        )
        modules = []
        name = None
        for line in result.stdout.splitlines():
            stripped = line.strip()
            if stripped.startswith("Name:"):
                name = stripped[5:].strip()
            elif stripped.startswith("Library file:") and name:
                lib_path = stripped[13:].strip()
                modules.append({"name": name, "lib_path": lib_path})
                name = None
        return modules
    except FileNotFoundError:
        return []
