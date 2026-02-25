#!/bin/bash
# lib/pkcs11.sh — OpenSC PKCS11 module registration in NSS databases
#
# Provides: cleanup_legacy_pkcs11, register_pkcs11_in_db, register_pkcs11_all,
#           unregister_pkcs11_all
#
# Uses modutil (not certutil) for PKCS11 provider module records in pkcs11.txt.
# Both tools come from the nss package; certutil handles certificate records,
# modutil handles PKCS11 module records.
#
# NSS OWNERSHIP RULE (enforced without exception):
# All modutil calls MUST run as $REAL_USER via `sudo -H -u "$REAL_USER"`.
# See KNOWN_ISSUES.md #P6.
#
# OPENSC_PKCS11_LIB is a local alias for the injected PKCS11_LIB variable.
# It is declared readonly at the top of this file per PLAN.md convention;
# all other lib files use $PKCS11_LIB directly.
#
# pkcs11-register note: silently misses Firefox on CachyOS because it
# hardcodes ~/.mozilla/firefox as the profile search path. The modutil
# calls above handle Firefox correctly. pkcs11-register is called as
# a supplemental best-effort step only. See KNOWN_ISSUES.md #P5.
#
# No set -euo pipefail — inherited from bash/install.sh or bash/uninstall.sh.

# Local alias for the Python-injected PKCS11_LIB environment variable.
# Guard for safe BATS re-sourcing.
[[ -v OPENSC_PKCS11_LIB  ]] || OPENSC_PKCS11_LIB="${PKCS11_LIB}"
[[ -v PKCS11_MODULE_NAME ]] || PKCS11_MODULE_NAME="CAC Module"

cleanup_legacy_pkcs11() {
    # Remove stale cackey/coolkey entries before registering OpenSC.
    # A broken legacy entry pointing to a missing library is found by the
    # browser first, causing silent auth failure. See KNOWN_ISSUES.md #P2.
    #
    # Usage: cleanup_legacy_pkcs11 <db_dir>
    local db_dir="$1"
    local legacy_name
    for legacy_name in "CAC Module" "CACKey" "coolkey" "libcoolkeypk11"; do
        if sudo -H -u "$REAL_USER" modutil \
                -dbdir "sql:$db_dir" -list 2>/dev/null | grep -qi "$legacy_name"; then
            log_info "Removing legacy PKCS11 entry '$legacy_name' from: $db_dir"
            sudo -H -u "$REAL_USER" modutil \
                -dbdir "sql:$db_dir" \
                -delete "$legacy_name" \
                -force 2>&1 | tee -a "$_CAC_LOG_FILE" > /dev/null || true
        fi
    done
}

register_pkcs11_in_db() {
    # Register the OpenSC PKCS11 module in the given NSS database.
    # Idempotent: skips if already registered. Non-fatal on modutil error.
    #
    # Usage: register_pkcs11_in_db <db_dir>
    local db_dir="$1"

    cleanup_legacy_pkcs11 "$db_dir"

    # Check if already registered — must run as $REAL_USER (NSS ownership rule)
    if sudo -H -u "$REAL_USER" modutil \
            -dbdir "sql:$db_dir" -list 2>/dev/null | grep -qi "opensc-pkcs11"; then
        log_info "OpenSC module already registered in: $db_dir"
        return 0
    fi

    log_info "Registering OpenSC PKCS11 module in: $db_dir"
    # -force suppresses the interactive "please restart your browser" prompt
    local s=0
    sudo -H -u "$REAL_USER" modutil \
        -dbdir "sql:$db_dir" \
        -add "$PKCS11_MODULE_NAME" \
        -libfile "$OPENSC_PKCS11_LIB" \
        -force 2>&1 | tee -a "$_CAC_LOG_FILE" > /dev/null || s=$?

    if [[ $s -ne 0 ]]; then
        log_warn "modutil returned $s for: $db_dir (non-fatal — see log)"
        return $s
    fi

    log_success "Registered PKCS11 module in: $db_dir"
    echo "ACTION:pkcs11_register|$db_dir|$PKCS11_MODULE_NAME|$OPENSC_PKCS11_LIB"
    echo "STATE:pkcs11_registered_in+=$db_dir"
}

register_pkcs11_all() {
    log_section "PKCS11 Module Registration"
    log_info "PKCS11 library: $OPENSC_PKCS11_LIB"

    if [[ ! -f "$OPENSC_PKCS11_LIB" ]]; then
        log_error "OpenSC PKCS11 library not found: $OPENSC_PKCS11_LIB"
        log_error "Ensure opensc is installed: pacman -S opensc"
        exit 1
    fi

    # Guard against an empty NSS_DATABASES array. An empty array causes the
    # loop below to complete zero iterations and return success, leaving no
    # browser configured for CAC auth with no error logged. This can happen
    # if NSS_DB_PATHS was not injected by the orchestrator or the import phase
    # did not populate state.nss_databases. See KNOWN_ISSUES.md Issue #5c.
    if [[ ${#NSS_DATABASES[@]} -eq 0 ]]; then
        log_error "NSS_DATABASES is empty — no databases to register the PKCS11 module in."
        log_error "Ensure the import phase completed and NSS_DB_PATHS is set."
        exit 1
    fi

    local db_dir
    for db_dir in "${NSS_DATABASES[@]}"; do
        register_pkcs11_in_db "$db_dir"
    done

    # pkcs11-register as supplemental best-effort step.
    # Handles ~/.pki/nssdb but silently misses Firefox on CachyOS
    # (searches ~/.mozilla/firefox, not ~/.config/mozilla/firefox).
    # The modutil calls above already cover Firefox correctly.
    if command -v pkcs11-register > /dev/null 2>&1; then
        log_info "Running pkcs11-register (supplemental — non-zero exit expected on CachyOS for Firefox)..."
        sudo -H -u "$REAL_USER" pkcs11-register 2>&1 | tee -a "$_CAC_LOG_FILE" > /dev/null || true
        log_info "pkcs11-register step complete."
    fi

    log_success "PKCS11 registration phase complete."
}

unregister_pkcs11_all() {
    # Remove the OpenSC PKCS11 module from all NSS databases listed in state.
    # Reads pkcs11_registered_in from $STATE_FILE via _state_read_list
    # (defined in lib/detect.sh).
    # Idempotent: skips databases where the module is already absent.
    # Must run modutil as $REAL_USER (NSS ownership rule).
    log_section "PKCS11 Module Unregistration"

    local registered_dbs=()
    mapfile -t registered_dbs < <(_state_read_list "pkcs11_registered_in")

    if [[ ${#registered_dbs[@]} -eq 0 ]]; then
        log_info "No PKCS11 registrations found in state — nothing to remove."
        return 0
    fi

    local db_dir
    for db_dir in "${registered_dbs[@]}"; do
        [[ -z "$db_dir" ]] && continue
        if [[ ! -d "$db_dir" ]]; then
            log_info "NSS database absent (already removed?): $db_dir"
            continue
        fi
        if sudo -H -u "$REAL_USER" modutil \
                -dbdir "sql:$db_dir" -list 2>/dev/null | grep -qi "CAC Module"; then
            log_info "Removing PKCS11 module from: $db_dir"
            sudo -H -u "$REAL_USER" modutil \
                -dbdir "sql:$db_dir" \
                -delete "$PKCS11_MODULE_NAME" \
                -force 2>&1 | tee -a "$_CAC_LOG_FILE" > /dev/null || true
            log_success "Removed PKCS11 module from: $db_dir"
            echo "ACTION:pkcs11_unregister|$db_dir|$PKCS11_MODULE_NAME"
        else
            log_info "PKCS11 module not registered in: $db_dir (already removed)"
        fi
    done

    log_success "PKCS11 unregistration phase complete."
}
