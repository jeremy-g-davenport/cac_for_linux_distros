#!/bin/bash
# lib/detect.sh — Environment validation for cac_for_linux_distros
#
# OS/arch detection is handled by Python (distros/detect.py). All distro-specific
# values (PKCS11_LIB, PCSCD_UNIT, REAL_USER, REAL_HOME, STATE_FILE) arrive as
# environment variables injected by the Python orchestrator before every Bash
# subprocess call. This file validates those vars and the runtime context.
#
# No set -euo pipefail — inherited from bash/install.sh or bash/uninstall.sh.

# Exit codes — guard with [[ -v ]] for safe re-sourcing in BATS
[[ -v E_NOTROOT    ]] || readonly E_NOTROOT=86
[[ -v E_BROWSER    ]] || readonly E_BROWSER=87
[[ -v E_DATABASE   ]] || readonly E_DATABASE=88
[[ -v E_NOARCH     ]] || readonly E_NOARCH=89
[[ -v E_NOTARCH    ]] || readonly E_NOTARCH=90
[[ -v E_NODEPS     ]] || readonly E_NODEPS=91
[[ -v E_CONFIG     ]] || readonly E_CONFIG=92
[[ -v EXIT_SUCCESS ]] || readonly EXIT_SUCCESS=0

validate_env() {
    # Asserts that Python injected all required environment variables.
    # Call this before any other function in bash/install.sh or bash/uninstall.sh.
    local required_vars=(PKCS11_LIB PCSCD_UNIT REAL_USER REAL_HOME STATE_FILE)
    local var
    for var in "${required_vars[@]}"; do
        [[ -n "${!var:-}" ]] || {
            log_error "Required env var not set: $var (should be injected by Python orchestrator)"
            exit "$E_CONFIG"
        }
    done
    log_info "Environment validated. User: $REAL_USER | PKCS11 lib: $PKCS11_LIB"
}

detect_root() {
    if [[ $(id -u) -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)."
        log_error "Example: sudo python3 cac_setup.py"
        exit "$E_NOTROOT"
    fi
}

detect_real_user() {
    if [[ -z "${REAL_USER:-}" ]]; then
        log_error "REAL_USER not set. Run via: sudo python3 cac_setup.py"
        exit "$E_NOTROOT"
    fi
    if [[ -z "${REAL_HOME:-}" ]]; then
        log_error "REAL_HOME not set. Run via: sudo python3 cac_setup.py"
        exit "$E_NOTROOT"
    fi
    log_info "Configuring for user: $REAL_USER (home: $REAL_HOME)"
}

detect_required_tools() {
    # Pre-install check: tools that must exist before packages are installed.
    local tool
    for tool in systemctl certutil modutil getent id cut grep find date sha256sum lsmod modprobe; do
        if ! command -v "$tool" > /dev/null 2>&1; then
            log_error "Required tool not found: $tool"
            exit "$E_NODEPS"
        fi
    done
    log_success "All prerequisite tools found."
}

detect_post_install_tools() {
    # Post-install check: tools provided by installed packages.
    # Call after install_official_packages() to confirm packages landed correctly.
    local tool
    for tool in opensc-tool wget unzip; do
        if ! command -v "$tool" > /dev/null 2>&1; then
            log_error "Post-install tool not found: $tool (package installation may have failed)"
            exit "$E_NODEPS"
        fi
    done
    log_success "All post-install tools found."
}

detect_conflicting_modules() {
    # The pn533 and nfc kernel modules claim the USB reader before pcscd can,
    # causing pcsc_scan and opensc-tool to report no readers. Unload them if present.
    # Source: M-Pepper linux-cac-walkthrough (Issue #P1 in KNOWN_ISSUES.md)
    local mod
    for mod in pn533 nfc; do
        if lsmod 2>/dev/null | grep -q "^${mod} "; then
            log_warn "Conflicting kernel module loaded: $mod — unloading..."
            if modprobe -r "$mod" 2>/dev/null; then
                log_success "Unloaded: $mod"
            else
                log_warn "Could not unload $mod — reader detection may fail"
            fi
        fi
    done
}

detect_to_json() {
    # Emits a single-line JSON object for Python's initial validation pass.
    # Python calls this to confirm Bash sees the injected environment correctly.
    printf '{"arch":"%s","user":"%s","pkcs11_lib":"%s"}\n' \
        "$(uname -m)" "${REAL_USER:-}" "${PKCS11_LIB:-}"
}
