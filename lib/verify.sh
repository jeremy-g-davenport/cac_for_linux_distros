#!/bin/bash
# lib/verify.sh — Post-install verification and optional Horizon symlink
#
# Provides: verify_pcscd, verify_pkcs11_registered, verify_certificates_imported,
#           verify_card_reader, verify_card_objects, run_verification,
#           configure_horizon_symlink
#
# NSS OWNERSHIP RULE (enforced without exception):
# All certutil and modutil calls MUST run as $REAL_USER via `sudo -H -u "$REAL_USER"`.
# See KNOWN_ISSUES.md #P6.
#
# OPENSC_PKCS11_LIB is a local alias for the injected PKCS11_LIB variable.
# Declared readonly here (and in lib/pkcs11.sh) per PLAN.md convention.
# All other lib files use $PKCS11_LIB directly.
#
# Step 10.5 (Horizon symlink) is an optional step bundled here because no
# separate branch exists for it in the branch table. configure_horizon_symlink
# is a no-op when neither VMware nor Omnissa Horizon is installed.
#
# No set -euo pipefail — inherited from bash/install.sh or bash/uninstall.sh.

# Local alias for the Python-injected PKCS11_LIB environment variable.
# Guards for safe BATS re-sourcing.
[[ -v OPENSC_PKCS11_LIB      ]] || readonly OPENSC_PKCS11_LIB="${PKCS11_LIB}"
[[ -v VMWARE_HORIZON_PKCS11  ]] || readonly VMWARE_HORIZON_PKCS11="/usr/lib/vmware/view/pkcs11/libopenscpkcs11.so"
[[ -v OMNISSA_HORIZON_PKCS11 ]] || readonly OMNISSA_HORIZON_PKCS11="/usr/lib/omnissa/horizon/pkcs11/libopenscpkcs11.so"

verify_pcscd() {
    # Check that pcscd.socket is active. Returns 1 (failure) if not.
    log_info "pcscd.socket status..."
    if verify_pcscd_service; then
        log_success "pcscd.socket is active."
        return 0
    else
        log_error "pcscd.socket is NOT active."
        return 1
    fi
}

verify_pkcs11_registered() {
    # Verify the OpenSC PKCS11 module appears in each NSS database.
    # Must run modutil as $REAL_USER (NSS ownership rule).
    # Returns 1 if any database is missing the registration.
    log_info "Verifying PKCS11 module registration..."
    local ok=0 bad=0
    local db_dir
    for db_dir in "${NSS_DATABASES[@]}"; do
        if sudo -H -u "$REAL_USER" modutil \
                -dbdir "sql:$db_dir" -list 2>/dev/null | grep -qi "opensc-pkcs11"; then
            log_success "  Registered: $db_dir"
            (( ok++ ))
        else
            log_error "  NOT registered: $db_dir"
            (( bad++ ))
        fi
    done
    [[ $bad -eq 0 ]]
}

verify_certificates_imported() {
    # Check that a meaningful number of certificates are present in each NSS database.
    # Warns (non-fatal) if the count is suspiciously low (≤10).
    # Must run certutil as $REAL_USER (NSS ownership rule).
    log_info "Verifying certificates in NSS databases..."
    local db_dir count
    for db_dir in "${NSS_DATABASES[@]}"; do
        count="$(sudo -H -u "$REAL_USER" certutil \
            -d "sql:$db_dir" -L 2>/dev/null | wc -l)"
        if [[ $count -gt 10 ]]; then
            log_success "  $count cert(s) found in: $db_dir"
        else
            log_warn "  Only $count cert(s) in: $db_dir — import may have failed"
        fi
    done
}

verify_card_reader() {
    # Check whether a PC/SC card reader is detected by OpenSC.
    # Non-fatal: the CAC reader may not be inserted during initial setup.
    log_info "Checking for connected card reader..."
    if ! command -v opensc-tool > /dev/null 2>&1; then
        log_info "opensc-tool not available — skipping reader check"
        return 0
    fi

    local output
    output="$(opensc-tool --list-readers 2>&1 || true)"
    if [[ -n "$output" ]]; then
        if echo "$output" | grep -qi "No smart card"; then
            log_warn "Reader driver active but no CAC inserted."
        else
            log_success "Card reader detected: $output"
        fi
    else
        log_info "No readers detected — insert your CAC reader and verify with: opensc-tool --list-readers"
    fi
}

verify_card_objects() {
    # Confirm the CAC is readable through OpenSC by listing PKCS11 objects.
    # Requires a physical CAC to be inserted — skipped with a warning if not.
    # Must run pkcs11-tool as $REAL_USER (NSS ownership rule).
    if ! command -v pkcs11-tool > /dev/null 2>&1; then
        log_info "pkcs11-tool not available — skipping card object check"
        return 0
    fi

    log_info "Listing CAC objects via pkcs11-tool..."
    local output
    output="$(sudo -H -u "$REAL_USER" pkcs11-tool \
        --module "$OPENSC_PKCS11_LIB" \
        --list-objects 2>&1 || true)"

    if echo "$output" | grep -qi "Certificate\|Private Key\|Public Key"; then
        log_success "CAC objects readable through OpenSC PKCS11."
        log_info "$output"
    elif echo "$output" | grep -qi "no token\|no card\|token not present"; then
        log_warn "No CAC inserted — insert card and re-run verification to confirm."
    else
        log_warn "pkcs11-tool returned unexpected output — review log: $_CAC_LOG_FILE"
        log_info "$output"
    fi
}

run_verification() {
    log_section "Post-Install Verification"
    local ok=true
    verify_pcscd             || ok=false
    verify_pkcs11_registered || ok=false
    verify_certificates_imported
    verify_card_reader
    verify_card_objects

    if [[ "$ok" == true ]]; then
        log_success "All critical verification checks passed."
        log_info "Recommendation: Reboot before first use."
    else
        log_warn "Some checks failed — review: $_CAC_LOG_FILE"
        log_warn "A reboot may still resolve these issues."
    fi
}

configure_horizon_symlink() {
    # Step 10.5 — Create symlink so VMware/Omnissa Horizon can find the OpenSC
    # PKCS11 library. Horizon ships its own pkcs11 directory and does not read
    # system NSS databases. No-op when neither Horizon installation is present.
    # See PLAN.md Step 10.5 and KNOWN_ISSUES.md for the VM reader-passthrough caveat.
    log_section "VMware/Omnissa Horizon PKCS11 (optional)"
    local target="$OPENSC_PKCS11_LIB"
    local link link_dir

    for link in "$VMWARE_HORIZON_PKCS11" "$OMNISSA_HORIZON_PKCS11"; do
        link_dir="$(dirname "$link")"
        if [[ -d "$link_dir" ]]; then
            if [[ -L "$link" ]]; then
                log_info "Horizon symlink already exists: $link"
            else
                ln -s "$target" "$link"
                log_success "Created Horizon symlink: $link -> $target"
                echo "ACTION:horizon_symlink|$link|$target"
            fi
        fi
    done
}
