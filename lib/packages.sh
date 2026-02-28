#!/bin/bash
# lib/packages.sh — Package installation for cac_for_linux_distros
#
# Provides: install_official_packages, is_package_installed, verify_certutil,
#           emit_packages_state, remove_smart_card_packages
#
# MAINTENANCE NOTE: REQUIRED_PACKAGES is also defined in distros/*/config.py.
# Both lists must be kept in sync per distro. The Bash list (populated from
# REQUIRED_PACKAGES_ENV injected by Python) is the executable authority;
# the Python list is used for pre-flight validation before Bash runs.
#
# Package management is driven by env vars injected by the Python orchestrator:
#   PKG_QUERY_CMD      — command to check if a package is installed (e.g. "pacman -Qi")
#   PKG_SYNC_CMD       — full sync+upgrade command (e.g. "pacman -Syu --noconfirm")
#   PKG_INSTALL_PREFIX — install command prefix, packages appended (e.g. "dnf install -y")
#   PKG_REMOVE_PREFIX  — remove command prefix, packages appended (e.g. "dnf remove -y")
#   REQUIRED_PACKAGES_ENV   — space-separated package list (overrides Arch defaults)
#   SMART_CARD_PACKAGES_ENV — space-separated smart-card-only list (overrides Arch defaults)
#
# All env vars fall back to Arch/pacman defaults when unset, preserving
# standalone developer mode (bash/install.sh --phase=packages without Python).
#
# No set -euo pipefail — inherited from bash/install.sh or bash/uninstall.sh.

# Populate REQUIRED_PACKAGES array from injected env var or Arch defaults.
# [[ -v ]] guard prevents re-declaration when BATS re-sources this file.
if [[ -v REQUIRED_PACKAGES ]]; then
    : # already set (BATS re-source guard)
elif [[ -n "${REQUIRED_PACKAGES_ENV:-}" ]]; then
    # shellcheck disable=SC2206
    read -ra REQUIRED_PACKAGES <<< "$REQUIRED_PACKAGES_ENV"
else
    REQUIRED_PACKAGES=(pcsclite ccid opensc nss pcsc-tools unzip wget)
fi

# Populate SMART_CARD_PACKAGES_LIST from injected env var or Arch defaults.
# Named SMART_CARD_PACKAGES_LIST to avoid collision with SMART_CARD_PACKAGES_ENV.
if [[ -v SMART_CARD_PACKAGES_LIST ]]; then
    : # already set (BATS re-source guard)
elif [[ -n "${SMART_CARD_PACKAGES_ENV:-}" ]]; then
    # shellcheck disable=SC2206
    read -ra SMART_CARD_PACKAGES_LIST <<< "$SMART_CARD_PACKAGES_ENV"
else
    SMART_CARD_PACKAGES_LIST=(pcsclite ccid opensc pcsc-tools)
fi

is_package_installed() {
    # Returns 0 if the package is installed, non-zero otherwise.
    # Uses PKG_QUERY_CMD injected by Python (e.g. "pacman -Qi" or "rpm -q").
    # Falls back to pacman for standalone developer use.
    local -a q
    # shellcheck disable=SC2206
    read -ra q <<< "${PKG_QUERY_CMD:-pacman -Qi}"
    "${q[@]}" "$1" > /dev/null 2>&1
}

_get_package_version() {
    # Extract the installed version string for a package.
    # Output format varies by package manager; returns "unknown" when unrecognised.
    local pkg="$1"
    case "${PKG_QUERY_CMD:-pacman -Qi}" in
        pacman*)
            pacman -Qi "$pkg" 2>/dev/null | awk '/^Version/{print $3; exit}'
            ;;
        rpm*)
            rpm -q --qf '%{VERSION}-%{RELEASE}\n' "$pkg" 2>/dev/null | head -1
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

install_official_packages() {
    log_section "Package Installation"

    # Sync package database and upgrade before installing.
    # For Arch/CachyOS (rolling release): PKG_SYNC_CMD is "pacman -Syu --noconfirm".
    # On Arch, never use -Sy alone — partial upgrade breaks system libraries.
    # For Red Hat: PKG_SYNC_CMD is "dnf upgrade -y".
    local -a sync_tokens
    # shellcheck disable=SC2206
    read -ra sync_tokens <<< "${PKG_SYNC_CMD:-pacman -Syu --noconfirm}"
    log_info "Syncing package database and upgrading system..."
    if ! log_cmd "${sync_tokens[@]}"; then
        log_error "System sync/upgrade failed. Check network connectivity."
        exit "$E_NODEPS"
    fi

    local to_install=()
    local pkg
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if is_package_installed "$pkg"; then
            log_info "Already installed: $pkg"
        else
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "Installing packages: ${to_install[*]}"
        local -a install_tokens
        # shellcheck disable=SC2206
        read -ra install_tokens <<< "${PKG_INSTALL_PREFIX:-pacman -S --needed --noconfirm}"
        if ! log_cmd "${install_tokens[@]}" "${to_install[@]}"; then
            log_error "Package installation failed. See log: $_CAC_LOG_FILE"
            exit "$E_NODEPS"
        fi
        log_success "Packages installed: ${to_install[*]}"
    else
        log_success "All required packages already present."
    fi

    emit_packages_state
}

verify_certutil() {
    # Confirms certutil and modutil are available after the packages phase.
    # On Arch they come from 'nss'; on Fedora/RHEL from 'nss-tools'.
    if ! command -v certutil > /dev/null 2>&1; then
        log_error "certutil not found after installing packages."
        log_error "The nss-tools (or nss) package may have failed to install."
        exit "$E_NODEPS"
    fi
    if ! command -v modutil > /dev/null 2>&1; then
        log_error "modutil not found after installing packages."
        log_error "The nss-tools (or nss) package may have failed to install."
        exit "$E_NODEPS"
    fi
    log_success "certutil and modutil confirmed: $(command -v certutil)"
}

emit_packages_state() {
    # Emit STATE: line so Python can record which packages were installed.
    # Collects the current installed version of each required package.
    local installed=()
    local pkg ver
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if is_package_installed "$pkg"; then
            ver="$(_get_package_version "$pkg")"
            installed+=("${pkg}=${ver}")
        fi
    done
    local IFS=','
    echo "STATE:packages_installed=${installed[*]}"
}

remove_smart_card_packages() {
    # Remove only smart-card-specific packages that were installed by this tool.
    # Reads packages_installed from $STATE_FILE via _state_read_list (lib/detect.sh).
    # Intersects with SMART_CARD_PACKAGES_LIST to avoid removing general utilities
    # (wget, unzip, nss/nss-tools).
    log_section "Package Removal"

    # Packages this tool installed (strip version suffixes: pkg=version → pkg)
    local installed_by_tool=()
    mapfile -t installed_by_tool < <(_state_read_list "packages_installed" \
        | sed 's/=.*//')

    local to_remove=()
    local pkg
    for pkg in "${SMART_CARD_PACKAGES_LIST[@]}"; do
        if printf '%s\n' "${installed_by_tool[@]}" | grep -qx "$pkg"; then
            if is_package_installed "$pkg"; then
                to_remove+=("$pkg")
            fi
        fi
    done

    if [[ ${#to_remove[@]} -eq 0 ]]; then
        log_info "No smart-card-specific packages to remove."
        return 0
    fi

    log_info "Removing packages: ${to_remove[*]}"
    local -a remove_tokens
    # shellcheck disable=SC2206
    read -ra remove_tokens <<< "${PKG_REMOVE_PREFIX:-pacman -Rns --noconfirm}"
    local s=0
    "${remove_tokens[@]}" "${to_remove[@]}" >> "$_CAC_LOG_FILE" 2>&1 || s=$?
    if [[ $s -ne 0 ]]; then
        log_warn "Package removal returned $s — packages may have already been removed (non-fatal)"
    else
        log_success "Packages removed: ${to_remove[*]}"
        echo "ACTION:packages_removed|${to_remove[*]}"
    fi
}
