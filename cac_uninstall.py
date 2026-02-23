#!/usr/bin/env python3
# cac_uninstall.py — CAC for Linux Distros uninstall entry point
#
# Usage: sudo python3 cac_uninstall.py
# All browsers must be closed before running.
import sys
import os
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from orchestrator.uninstall_flow import run_uninstall
from orchestrator.state import InstallState
from distros.detect import detect_distro


def main() -> None:
    if os.geteuid() != 0:
        print("[ERROR] Run with sudo: sudo python3 cac_uninstall.py", file=sys.stderr)
        sys.exit(86)

    try:
        state = InstallState.load()
    except FileNotFoundError:
        print("[ERROR] No state file at /var/lib/cac_for_linux_distros/state.json")
        print("        If installed manually, see README.md for manual uninstall steps")
        sys.exit(1)

    _, driver = detect_distro()
    run_uninstall(state=state, driver=driver)


if __name__ == "__main__":
    main()
