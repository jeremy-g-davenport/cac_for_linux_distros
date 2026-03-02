#!/bin/bash
# lib/detect.sh — Environment validation for cac_for_linux_distros
#
# Provides: validate_env, detect_root, detect_real_user, detect_required_tools,
#           detect_selinux, detect_post_install_tools, detect_conflicting_modules,
#           detect_to_json, _state_read_list, remove_state_and_logs
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
    # certutil and modutil are intentionally NOT in the fatal list — they are
    # provided by nss/nss-tools which is installed in the packages phase.
    # They are verified post-install by verify_certutil() in packages.sh.
    local tool
    for tool in systemctl getent id cut grep find date sha256sum lsmod modprobe; do
        if ! command -v "$tool" > /dev/null 2>&1; then
            log_error "Required tool not found: $tool"
            exit "$E_NODEPS"
        fi
    done
    # certutil/modutil: warn if absent — they arrive via the packages phase.
    for tool in certutil modutil; do
        if ! command -v "$tool" > /dev/null 2>&1; then
            log_warn "Tool not yet available: $tool (will be installed in packages phase)"
        fi
    done
    log_success "All prerequisite tools found."
}

detect_selinux() {
    # Informational only — SELinux enforcing mode does not prevent CAC setup,
    # but unexpected AVC denials can silently block pcscd socket access.
    # This function is a no-op on Arch and other non-SELinux systems where
    # getenforce is absent.
    command -v getenforce > /dev/null 2>&1 || return 0
    local mode
    mode="$(getenforce 2>/dev/null || echo 'Unknown')"
    if [[ "$mode" == "Enforcing" ]]; then
        log_warn "SELinux is Enforcing. pcscd policies should be covered by pcsc-lite-selinux."
        log_warn "If card access fails after install, run: sudo ausearch -m avc -ts recent"
    else
        log_info "SELinux mode: $mode"
    fi
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

_state_read_list() {
    # Usage: _state_read_list <json_key>
    # Reads a JSON array from $STATE_FILE, printing one item per line.
    # Silent no-op if STATE_FILE is missing, unreadable, or the key is absent.
    python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    [print(i) for i in d.get(sys.argv[2], []) if i]
except Exception:
    pass
" "$STATE_FILE" "$1" 2>/dev/null || true
}

remove_state_and_logs() {
    # Remove Horizon symlinks, log files, and the state directory.
    # Must be called LAST in the uninstall sequence — state is gone after this.
    # Horizon symlinks are identified by the constants in lib/verify.sh (sourced
    # before this function is invoked).
    log_section "Cleanup: State and Logs"

    # Remove Horizon symlinks if they are symlinks created by this tool
    local link
    for link in "${VMWARE_HORIZON_PKCS11:-}" "${OMNISSA_HORIZON_PKCS11:-}"; do
        [[ -z "$link" ]] && continue
        if [[ -L "$link" ]]; then
            rm -f "$link"
            log_success "Removed Horizon symlink: $link"
            echo "ACTION:horizon_symlink_removed|$link"
        fi
    done

    # Remove log files
    local log_file
    for log_file in /var/log/cac_for_linux_distros_*.log; do
        [[ -f "$log_file" ]] || continue
        rm -f "$log_file"
        log_success "Removed log: $log_file"
    done

    # Remove state directory last (can no longer read state after this)
    local state_dir="/var/lib/cac_for_linux_distros"
    if [[ -d "$state_dir" ]]; then
        rm -rf "$state_dir"
        log_success "Removed state directory: $state_dir"
    else
        log_info "State directory already absent: $state_dir"
    fi

    log_success "Cleanup complete."
}
