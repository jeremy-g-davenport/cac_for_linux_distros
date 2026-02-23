#!/bin/bash
# lib/import.sh — DoD certificate import into NSS databases
#
# Provides: import_certs_into_db, import_all_certs, remove_all_certs
#
# NSS OWNERSHIP RULE (enforced without exception):
# All certutil calls MUST run as $REAL_USER via `sudo -H -u "$REAL_USER"`.
# Files written by root to a user-owned NSS database are unreadable by the
# browser process, silently breaking CAC authentication. See KNOWN_ISSUES.md #P6.
#
# Trust flags: `-t TC`
#   T = trusted CA for SSL/TLS server certificate verification
#   C = trusted CA certificate
# This is the correct level for DoD root CAs. Operators with stricter
# policies may use `-t C,C,` (CA only) or `-t ,C,` (CA, not trusted for auth).
#
# Certificate tracking: each successful import emits STATE:imported_cert_nicknames+=<name>
# Python appends each name to state.imported_cert_nicknames in state.json.
# The uninstall flow reads state.imported_cert_nicknames for exact-match
# removal via `certutil -D -n <nickname>`.
#
# No set -euo pipefail — inherited from bash/install.sh or bash/uninstall.sh.

import_certs_into_db() {
    # Import all CERT_FILES into the given NSS database directory.
    # Non-fatal on individual certificate failures (some may be corrupt or
    # have unexpected formatting; the rest should still import successfully).
    #
    # Usage: import_certs_into_db <db_dir>
    local db_dir="$1"

    # Human-readable label for log output
    local label="NSS database"
    if [[ "$db_dir" == *mozilla* ]] || [[ "$db_dir" == *firefox* ]]; then
        label="Firefox"
    elif [[ "$db_dir" == *pki* ]]; then
        label="Chromium (shared)"
    fi

    log_section "Importing certificates — $label"
    log_info "Database: $db_dir"

    local imported=0 skipped=0 failed=0
    local cert_file cert_name

    # Sort certs alphabetically by basename. DoD bundle names root CAs as
    # "DoD_Root_CA_*" and intermediates as "DoD_CA_*", so lexicographic order
    # naturally places roots first — chains validate during import.
    local sorted_cert_files
    mapfile -t sorted_cert_files < <(printf '%s\n' "${CERT_FILES[@]}" | sort -t/ -k4,4)

    for cert_file in "${sorted_cert_files[@]}"; do
        cert_name="$(basename "$cert_file")"

        # Skip if already present — must run as $REAL_USER (NSS ownership rule)
        if sudo -H -u "$REAL_USER" certutil \
                -d "sql:$db_dir" -L -n "$cert_name" > /dev/null 2>&1; then
            (( skipped++ ))
            continue
        fi

        # Import as $REAL_USER with TC trust flags
        local s=0
        sudo -H -u "$REAL_USER" certutil \
            -d "sql:$db_dir" \
            -A -t "TC" \
            -n "$cert_name" \
            -i "$cert_file" >> "$_CAC_LOG_FILE" 2>&1 || s=$?

        if [[ $s -eq 0 ]]; then
            (( imported++ ))
            # Emit for Python to append to state.imported_cert_nicknames
            echo "STATE:imported_cert_nicknames+=$cert_name"
            echo "ACTION:cert_import|$db_dir|$cert_name|TC"
        else
            (( failed++ ))
            log_warn "  Failed to import: $cert_name (non-fatal, continuing)"
        fi
    done

    log_success "$label: imported=$imported skipped=$skipped failed=$failed"
    if [[ $failed -gt 0 ]]; then
        log_warn "  $failed failure(s) — check log for details: $_CAC_LOG_FILE"
    fi
}

import_all_certs() {
    log_section "Certificate Import"
    if [[ ${#CERT_FILES[@]} -eq 0 ]]; then
        log_error "No certificate files available. Run extract_certs first."
        exit 1
    fi

    local db_dir
    for db_dir in "${NSS_DATABASES[@]}"; do
        import_certs_into_db "$db_dir"
    done

    log_success "Certificate import phase complete."
}

remove_all_certs() {
    # Remove DoD CA certificates from all NSS databases listed in state.
    # Reads nss_databases and imported_cert_nicknames from $STATE_FILE via
    # _state_read_list (defined in lib/detect.sh).
    # Uses exact nickname match from state — safe to run multiple times (idempotent).
    # Must run certutil as $REAL_USER (NSS ownership rule).
    log_section "Certificate Removal"

    local nss_dbs=() nicknames=()
    mapfile -t nss_dbs   < <(_state_read_list "nss_databases")
    mapfile -t nicknames < <(_state_read_list "imported_cert_nicknames")

    if [[ ${#nss_dbs[@]} -eq 0 ]] || [[ ${#nicknames[@]} -eq 0 ]]; then
        log_info "No certificate removal entries found in state — nothing to do."
        return 0
    fi

    local db_dir nick
    for db_dir in "${nss_dbs[@]}"; do
        [[ -z "$db_dir" ]] && continue
        if [[ ! -d "$db_dir" ]]; then
            log_info "NSS database absent (already removed?): $db_dir"
            continue
        fi
        log_info "Removing certificates from: $db_dir"
        local removed=0 skipped=0
        for nick in "${nicknames[@]}"; do
            [[ -z "$nick" ]] && continue
            if sudo -H -u "$REAL_USER" certutil \
                    -d "sql:$db_dir" -L -n "$nick" > /dev/null 2>&1; then
                sudo -H -u "$REAL_USER" certutil \
                    -d "sql:$db_dir" -D -n "$nick" >> "$_CAC_LOG_FILE" 2>&1 || true
                (( removed++ ))
            else
                (( skipped++ ))
            fi
        done
        log_success "  Removed $removed cert(s), skipped $skipped (already absent)"
        echo "ACTION:certs_removed|$db_dir|count=$removed"
    done

    log_success "Certificate removal phase complete."
}
