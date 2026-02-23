#!/bin/bash
# tests/helpers/set_test_env.sh — Export required env vars with Arch defaults.
#
# Usage: source tests/helpers/set_test_env.sh
#
# Required when running bash/install.sh or bash/uninstall.sh directly
# (without the Python orchestrator) for integration testing.
# Python normally injects these via orchestrator/runner.py _build_env().

export PKCS11_LIB="/usr/lib/opensc-pkcs11.so"
export PCSCD_UNIT="pcscd.socket"
export REAL_USER="${SUDO_USER:-$USER}"
export REAL_HOME="${HOME}"
export STATE_FILE="/var/lib/cac_for_linux_distros/state.json"
