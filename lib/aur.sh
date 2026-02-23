#!/bin/bash
# lib/aur.sh — AUR helper detection and package installation
#
# Provides: detect_aur_helper, aur_install
#
# AUR helpers (paru, yay) MUST NOT be run as root. aur_install drops to
# $REAL_USER via `sudo -H -u "$REAL_USER"` for every invocation.
# Used for AUR-only browsers: google-chrome, microsoft-edge-stable-bin, brave-bin.
#
# No set -euo pipefail — inherited from bash/install.sh or bash/uninstall.sh.

_AUR_HELPER=""

detect_aur_helper() {
    # Populate $_AUR_HELPER with the first available AUR helper.
    # Preference: paru (CachyOS default) then yay.
    if command -v paru > /dev/null 2>&1; then
        _AUR_HELPER="paru"
        log_info "AUR helper: paru"
    elif command -v yay > /dev/null 2>&1; then
        _AUR_HELPER="yay"
        log_info "AUR helper: yay"
    else
        _AUR_HELPER=""
        log_warn "No AUR helper found. AUR packages (Google Chrome, Edge, Brave) cannot be installed."
        log_warn "Install paru or yay, then re-run if those browsers are needed."
    fi
}

aur_install() {
    # Install an AUR package as $REAL_USER (AUR helpers refuse to run as root).
    # Returns 1 gracefully if no AUR helper is available — non-fatal by design,
    # since AUR browsers are optional. Failures are logged as warnings.
    #
    # Usage: aur_install <package_name>
    local pkg="$1"
    if [[ -z "$_AUR_HELPER" ]]; then
        log_warn "Cannot install AUR package $pkg: no AUR helper available."
        return 1
    fi
    log_info "Installing AUR package: $pkg (as $REAL_USER)"
    local s=0
    sudo -H -u "$REAL_USER" "$_AUR_HELPER" -S --noconfirm "$pkg" >> "$_CAC_LOG_FILE" 2>&1 || s=$?
    if [[ $s -ne 0 ]]; then
        log_warn "Failed to install AUR package: $pkg (non-fatal, continuing)"
        return $s
    fi
    log_success "AUR package installed: $pkg"
    return 0
}
