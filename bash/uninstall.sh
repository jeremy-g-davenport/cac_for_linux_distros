#!/bin/bash
# bash/uninstall.sh — CAC uninstall execution unit
#
# Called by cac_uninstall.py via orchestrator/runner.py with --phase=<name>.
# All distro-specific values arrive as environment variables from Python.
# Do NOT add orchestration logic here — Python is the orchestrator.
#
# Usage (via Python):
#   python orchestrator invokes: bash bash/uninstall.sh --phase=<name>
#
# Developer standalone escape hatch (all phases, no Python):
#   export PKCS11_LIB=/usr/lib/opensc-pkcs11.so PCSCD_UNIT=pcscd.socket \
#          REAL_USER=$USER REAL_HOME=$HOME STATE_FILE=/var/lib/cac_for_linux_distros/state.json
#   sudo bash bash/uninstall.sh --phase=all
#
# No sourcing of set -euo pipefail by lib/*.sh — this file declares it for them.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE="${1:---phase=all}"

for lib_file in log detect service browser import pkcs11 packages verify; do
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/$lib_file.sh"
done

validate_env
log_init

case "$PHASE" in
    --phase=preflight)
        detect_root
        detect_real_user
        check_browsers_closed
        ;;

    --phase=pkcs11)
        unregister_pkcs11_all
        ;;

    --phase=certs)
        remove_all_certs
        ;;

    --phase=service)
        disable_pcscd
        ;;

    --phase=packages)
        remove_smart_card_packages
        ;;

    --phase=cleanup)
        remove_state_and_logs
        ;;

    --phase=verify)
        run_uninstall_verification
        ;;

    --phase=certs-only)
        # Targeted restore: remove certs only, no packages/services
        remove_all_certs
        ;;

    --phase=pkcs11-only)
        # Targeted restore: remove PKCS11 only, no packages/services
        unregister_pkcs11_all
        ;;

    --phase=all | all)
        # Developer escape hatch: run all phases without Python.
        # REQUIRES: export PKCS11_LIB PCSCD_UNIT REAL_USER REAL_HOME STATE_FILE before running.
        log_section "CAC for Linux Distros — Uninstall (standalone mode)"
        detect_root
        detect_real_user
        check_browsers_closed
        unregister_pkcs11_all
        remove_all_certs
        disable_pcscd
        remove_smart_card_packages
        remove_state_and_logs
        run_uninstall_verification
        ;;

    *)
        echo "[ERROR] Unknown phase: $PHASE" >&2
        exit 1
        ;;
esac
