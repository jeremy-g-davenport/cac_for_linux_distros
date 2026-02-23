#!/bin/bash
# bash/install.sh — CAC install execution unit
#
# Called by cac_setup.py via orchestrator/runner.py with --phase=<name>.
# All distro-specific values arrive as environment variables from Python.
# Do NOT add orchestration logic here — Python is the orchestrator.
#
# Usage (via Python):
#   python orchestrator invokes: bash bash/install.sh --phase=<name>
#
# Developer standalone escape hatch (all phases, no Python):
#   export PKCS11_LIB=/usr/lib/opensc-pkcs11.so PCSCD_UNIT=pcscd.socket \
#          REAL_USER=$USER REAL_HOME=$HOME STATE_FILE=/var/lib/cac_for_linux_distros/state.json
#   sudo bash bash/install.sh --phase=all
#
# No sourcing of set -euo pipefail by lib/*.sh — this file declares it for them.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE="${1:---phase=all}"

for lib_file in log detect aur packages opensc_conf service certs browser import pkcs11 verify; do
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/$lib_file.sh"
done

validate_env
log_init

case "$PHASE" in
    --phase=preflight)
        log_section "Phase 1: Pre-flight Checks"
        detect_root
        detect_real_user
        detect_required_tools
        check_browsers_closed
        ;;

    --phase=packages)
        log_section "Phase 2: Package Installation"
        detect_aur_helper
        install_official_packages
        verify_certutil
        detect_post_install_tools
        ;;

    --phase=opensc-conf)
        log_section "Phase 2.5: OpenSC Configuration"
        configure_opensc_cac_driver
        ;;

    --phase=service)
        log_section "Phase 3: Smart Card Daemon"
        detect_conflicting_modules
        record_pcscd_state
        enable_pcscd
        ;;

    --phase=certs)
        log_section "Phase 4: Certificate Download"
        download_certs
        validate_cert_bundle
        extract_certs
        ;;

    --phase=import)
        log_section "Phase 5: Browser and Certificate Setup"
        discover_databases
        import_all_certs
        ;;

    --phase=pkcs11)
        log_section "Phase 6: PKCS11 Module Registration"
        register_pkcs11_all
        ;;

    --phase=verify)
        log_section "Phase 7: Cleanup and Verification"
        cleanup_certs
        run_verification
        configure_horizon_symlink
        ;;

    --phase=certs-only)
        # Snapshot restore: import only, no packages/services
        import_all_certs
        ;;

    --phase=pkcs11-only)
        # Snapshot restore: PKCS11 only, no packages/services
        register_pkcs11_all
        ;;

    --phase=all | all)
        # Developer escape hatch: run all phases without Python.
        # REQUIRES: export PKCS11_LIB PCSCD_UNIT REAL_USER REAL_HOME STATE_FILE before running.
        # See tests/helpers/set_test_env.sh for a test wrapper.
        log_section "CAC for Linux Distros — Setup (standalone mode)"
        detect_root
        detect_real_user
        detect_required_tools
        check_browsers_closed
        detect_aur_helper
        install_official_packages
        verify_certutil
        detect_post_install_tools
        configure_opensc_cac_driver
        detect_conflicting_modules
        record_pcscd_state
        enable_pcscd
        download_certs
        validate_cert_bundle
        extract_certs
        discover_databases
        import_all_certs
        register_pkcs11_all
        cleanup_certs
        run_verification
        configure_horizon_symlink
        ;;

    *)
        echo "[ERROR] Unknown phase: $PHASE" >&2
        exit 1
        ;;
esac
