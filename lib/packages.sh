#!/bin/bash
# lib/packages.sh — Package installation for cac_for_linux_distros
#
# Provides: install_official_packages, is_package_installed, verify_certutil,
#           emit_packages_state, remove_smart_card_packages
#
# MAINTENANCE NOTE: REQUIRED_PACKAGES is also defined in distros/arch/config.py.
# Both lists must be kept in sync. The Bash list is the executable authority;
# the Python list is used for pre-flight validation before Bash runs.
#
# No set -euo pipefail — inherited from bash/install.sh or bash/uninstall.sh.

# Guard with [[ -v ]] for safe BATS re-sourcing
[[ -v REQUIRED_PACKAGES ]] || readonly REQUIRED_PACKAGES=(pcsclite ccid opensc nss pcsc-tools unzip wget)

is_package_installed() {
    # Returns 0 if the package is known to pacman, non-zero otherwise.
    pacman -Qi "$1" > /dev/null 2>&1
}

install_official_packages() {
    log_section "Package Installation"

    # IMPORTANT: On Arch/CachyOS (rolling release), `pacman -Sy` without `-u`
    # is a "partial upgrade" that can break installed packages by installing
    # newer deps against older system libraries. Always `pacman -Syu` first.
    log_info "Syncing package database and upgrading system..."
    if ! log_cmd pacman -Syu --noconfirm; then
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
        if ! log_cmd pacman -S --needed --noconfirm "${to_install[@]}"; then
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
    # Confirms the nss package landed correctly.
    if ! command -v certutil > /dev/null 2>&1; then
        log_error "certutil not found after installing nss. Try: pacman -S nss"
        exit "$E_NODEPS"
    fi
    if ! command -v modutil > /dev/null 2>&1; then
        log_error "modutil not found after installing nss. Try: pacman -S nss"
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
            ver="$(pacman -Qi "$pkg" 2>/dev/null | awk '/^Version/{print $3; exit}')"
            installed+=("${pkg}=${ver}")
        fi
    done
    local IFS=','
    echo "STATE:packages_installed=${installed[*]}"
}

remove_smart_card_packages() {
    # Remove only smart-card-specific packages that were installed by this tool.
    # Reads packages_installed from $STATE_FILE via _state_read_list (lib/detect.sh).
    # Intersects with SMART_CARD_ONLY to avoid removing general utilities (wget, unzip).
    # Uses `pacman -Rs` to also remove orphaned dependencies.
    log_section "Package Removal"

    # Packages this tool installed
    local installed_by_tool=()
    mapfile -t installed_by_tool < <(_state_read_list "packages_installed" \
        | sed 's/=.*//')   # strip version suffixes (pkg=version → pkg)

    # Packages safe to remove (smart-card-specific only; not wget/unzip/nss)
    local smart_card_only=(pcsclite ccid opensc pcsc-tools)
    local to_remove=()
    local pkg
    for pkg in "${smart_card_only[@]}"; do
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
    local s=0
    pacman -Rs --noconfirm "${to_remove[@]}" >> "$_CAC_LOG_FILE" 2>&1 || s=$?
    if [[ $s -ne 0 ]]; then
        log_warn "pacman -Rs returned $s — packages may have already been removed (non-fatal)"
    else
        log_success "Packages removed: ${to_remove[*]}"
        echo "ACTION:packages_removed|${to_remove[*]}"
    fi
}
