#!/usr/bin/env python3
# cac_setup.py — CAC for Linux Distros install entry point
#
# Usage: sudo python3 cac_setup.py
# All browsers must be closed before running.
import sys
import os
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from orchestrator.setup_flow import run_setup
from distros.detect import detect_distro


def main() -> None:
    if os.geteuid() != 0:
        print("[ERROR] Run with sudo: sudo python3 cac_setup.py", file=sys.stderr)
        sys.exit(86)

    sudo_user = os.environ.get("SUDO_USER", "")
    if not sudo_user:
        print("[ERROR] SUDO_USER not set. Run: sudo python3 cac_setup.py", file=sys.stderr)
        sys.exit(86)

    try:
        distro_info, driver = detect_distro()
    except RuntimeError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        sys.exit(1)

    print(f"[INFO]  Detected: {distro_info.pretty_name} ({distro_info.arch})")
    print(f"[INFO]  User: {sudo_user}")
    run_setup(driver=driver, sudo_user=sudo_user)


if __name__ == "__main__":
    main()
