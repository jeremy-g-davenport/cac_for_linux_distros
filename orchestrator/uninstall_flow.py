"""
uninstall_flow.py — Reversal sequencer for CAC uninstall.

Reads state.json and action_log.json to reverse only what was actually
completed. Idempotent: skips actions already marked reversed=True.
Conditionally skips pcscd disable if pcscd_was_active_before is True
(i.e. pcscd was running before setup — it should remain running).
"""
from __future__ import annotations

from pathlib import Path
from typing import Callable

from .action_log import load_log, mark_reversed
from .cancellation import CancellationToken
from .runner import stream_bash
from .state import InstallState

BASH_DIR = Path(__file__).parent.parent / "bash"
UNINSTALL_SCRIPT = BASH_DIR / "uninstall.sh"

UNINSTALL_PHASES = [
    "pkcs11",    # modutil: unregister OpenSC PKCS11 module
    "certs",     # certutil: remove imported DoD CA certs
    "service",   # disable pcscd.socket (if pcscd_was_active_before is False)
    "packages",  # optionally remove smart card packages
]


def run_uninstall(
    state: InstallState,
    driver,
    cancel_token: CancellationToken | None = None,
    progress_cb: Callable[[str], None] | None = None,
) -> None:
    """
    Reverse the CAC installation described by state.

    Skips phases that have already been reversed (idempotent).
    """
    from .setup_flow import _build_env

    env = _build_env(driver, state.real_user, state)
    env["NSS_DB_PATHS"] = ":".join(state.nss_databases)
    env["IMPORTED_CERT_NICKNAMES"] = ",".join(state.imported_cert_nicknames)
    env["PKCS11_REGISTERED_IN"] = ":".join(state.pkcs11_registered_in)
    env["PCSCD_WAS_ACTIVE_BEFORE"] = "1" if state.pcscd_was_active_before else "0"
    env["PACKAGES_INSTALLED"] = ",".join(state.packages_installed)

    for phase in UNINSTALL_PHASES:
        if cancel_token:
            cancel_token.check()

        if phase == "service" and state.pcscd_was_active_before:
            if progress_cb:
                progress_cb("[SKIP] pcscd was active before install — leaving enabled")
            continue

        if progress_cb:
            progress_cb(f"[PHASE] uninstall:{phase}")

        for line in stream_bash(
            UNINSTALL_SCRIPT,
            f"--phase={phase}",
            env=env,
            cancel_token=cancel_token,
        ):
            if progress_cb:
                progress_cb(line)

    _mark_actions_reversed()


def _mark_actions_reversed() -> None:
    """Mark all action log entries as reversed."""
    for record in load_log():
        if not record.reversed:
            mark_reversed(record.timestamp)
