"""
setup_flow.py — Phase sequencer for CAC setup.

Calls bash/install.sh --phase=<N> for each of the 7 install phases.
Parses STATE: and ACTION: prefixes from Bash stdout to update
InstallState and ActionRecord audit log. On CancellationError,
automatically triggers run_uninstall() for rollback.
"""
from __future__ import annotations

import time
from pathlib import Path
from typing import Callable

from .action_log import ActionRecord, append_action
from .cancellation import CancellationError, CancellationToken
from .runner import stream_bash
from .state import InstallState

BASH_DIR = Path(__file__).parent.parent / "bash"
INSTALL_SCRIPT = BASH_DIR / "install.sh"

# 8 install phases executed in order.
# Each name maps directly to --phase=<name> in bash/install.sh.
# Cross-check against the --phase=all case in install.sh whenever adding phases.
PHASES = [
    "preflight",    # detect distro/arch, check root, check browsers closed
    "packages",     # pacman -Syu + install required packages
    "opensc-conf",  # write force_card_driver = cac to /etc/opensc/opensc.conf
    "service",      # detect conflicting kernel modules; enable + start pcscd.socket
    "certs",        # download and extract DoD AllCerts.zip
    "import",       # discover NSS databases; certutil import all DoD CA certs
    "pkcs11",       # modutil: register OpenSC PKCS11 module in each NSS db
    "verify",       # cleanup staging dir; post-install verification
]


def run_setup(
    driver,
    sudo_user: str,
    cancel_token: CancellationToken | None = None,
    progress_cb: Callable[[str], None] | None = None,
    phase_cb: Callable[[str], None] | None = None,
) -> InstallState:
    """
    Run the full CAC install sequence.

    Returns the final InstallState on success.
    On CancellationError: triggers rollback then re-raises.
    """
    from .uninstall_flow import run_uninstall

    state = InstallState(
        distro_id=driver.distro_info.distro_id if hasattr(driver, "distro_info") else "",
        arch=driver.distro_info.arch if hasattr(driver, "distro_info") else "",
        real_user=sudo_user,
        install_timestamp=time.time(),
    )

    env = _build_env(driver, sudo_user, state)

    try:
        for phase in PHASES:
            if cancel_token:
                cancel_token.check()

            if phase_cb:
                phase_cb(phase)

            if progress_cb:
                progress_cb(f"[PHASE] {phase}")

            _run_phase(phase, env, state, cancel_token, progress_cb)
            state.save()

    except CancellationError:
        if progress_cb:
            progress_cb("[CANCEL] Rolling back...")
        run_uninstall(state, driver, cancel_token=CancellationToken(), progress_cb=progress_cb)
        raise

    return state


def _run_phase(
    phase: str,
    env: dict,
    state: InstallState,
    cancel_token: CancellationToken | None,
    progress_cb: Callable[[str], None] | None,
) -> None:
    for line in stream_bash(
        INSTALL_SCRIPT,
        f"--phase={phase}",
        env=env,
        cancel_token=cancel_token,
    ):
        _parse_line(line, state, progress_cb)


def _parse_line(
    line: str,
    state: InstallState,
    progress_cb: Callable[[str], None] | None,
) -> None:
    if line.startswith("STATE:"):
        key, _, val = line[6:].partition("=")
        key = key.strip()
        _apply_state(key, val, state)
    elif line.startswith("ACTION:"):
        parts = line[7:].split("|")
        if len(parts) >= 2:
            action_type = parts[0]
            target = parts[1]
            detail = _parse_action_detail(action_type, parts[2:])
            append_action(ActionRecord(
                timestamp=time.time(),
                action=action_type,
                target=target,
                detail=detail,
            ))
    else:
        if progress_cb:
            progress_cb(line)


def _apply_state(key: str, val: str, state: InstallState) -> None:
    """Update InstallState field by key name from a STATE: line."""
    if key == "distro_id":
        state.distro_id = val
    elif key == "arch":
        state.arch = val
    elif key == "real_user":
        state.real_user = val
    elif key == "packages_installed":
        state.packages_installed = [p for p in val.split(",") if p]
    elif key == "pcscd_was_active_before":
        state.pcscd_was_active_before = val.lower() in ("1", "true", "yes")
    elif key == "cert_bundle_sha256":
        state.cert_bundle_sha256 = val
    elif key == "nss_databases":
        state.nss_databases = [p for p in val.split(":") if p]
    elif key == "imported_cert_nicknames":
        state.imported_cert_nicknames = [n for n in val.split(",") if n]
    elif key == "pkcs11_registered_in":
        state.pkcs11_registered_in = [p for p in val.split(":") if p]


def _parse_action_detail(action_type: str, extra: list[str]) -> dict:
    """Convert pipe-delimited extra fields into a detail dict."""
    if action_type == "cert_import" and len(extra) >= 3:
        return {"trust_flags": extra[0], "cert_sha256": extra[1]}
    if action_type == "pkcs11_register" and len(extra) >= 2:
        return {"module_name": extra[0], "lib_path": extra[1]}
    if action_type == "pkg_install" and len(extra) >= 2:
        version = extra[0]
        was_present = extra[1].endswith("true") if len(extra) > 1 else False
        return {"version": version, "was_present_before": was_present}
    if action_type == "service_start" and len(extra) >= 1:
        return {"was_active_before": extra[0].endswith("true")}
    if action_type == "service_enable" and len(extra) >= 1:
        return {"was_enabled_before": extra[0].endswith("true")}
    return {"raw": extra}


def _build_env(driver, sudo_user: str, state: InstallState) -> dict:
    """Build the environment dict injected into every Bash subprocess."""
    import os
    env = os.environ.copy()
    env["PKCS11_LIB"] = driver.pkcs11_lib_path
    env["PCSCD_UNIT"] = driver.pcscd_unit
    env["REAL_USER"] = sudo_user
    env["STATE_FILE"] = "/var/lib/cac_for_linux_distros/state.json"
    if state.nss_databases:
        env["NSS_DB_PATHS"] = ":".join(state.nss_databases)
    # Resolve REAL_HOME from passwd
    try:
        import pwd
        env["REAL_HOME"] = pwd.getpwnam(sudo_user).pw_dir
    except (KeyError, ImportError):
        env["REAL_HOME"] = f"/home/{sudo_user}"
    return env
