#!/bin/bash
# lib/certs.sh — DoD certificate bundle download, validation, and extraction
#
# Provides: download_certs, validate_cert_bundle, extract_certs, cleanup_certs
#
# Downloads AllCerts.zip from militarycac.com into a PID-unique staging
# directory, validates its SHA-256 checksum (warn on mismatch, non-fatal
# since DoD periodically refreshes the bundle), and extracts all .cer files.
# Addresses KNOWN_ISSUES.md #P9 (checksum drift) and W5, W6 from PLAN.md.
#
# No set -euo pipefail — inherited from bash/install.sh or bash/uninstall.sh.

# Guard readonly vars for safe BATS re-sourcing
[[ -v CERT_URL       ]] || readonly CERT_URL="https://militarycac.com/maccerts/AllCerts.zip"
[[ -v BUNDLE_NAME    ]] || readonly BUNDLE_NAME="AllCerts.zip"
[[ -v CERT_DIR_NAME  ]] || readonly CERT_DIR_NAME="AllCerts"

# Fixed staging directory shared across all phase subprocesses.
# Using a PID-based path ($$) would create a different directory in each
# subprocess invoked by the Python orchestrator — the certs phase and the
# import/verify phases would each see a different, non-existent path.
# BATS unit tests override this via DWNLD_DIR="$BATS_TMPDIR/cac_test_$$"
# in their setup() function, so the guard preserves that isolation.
DWNLD_DIR="${DWNLD_DIR:-/tmp/cac_for_linux_distros_staging}"

# Known-good SHA-256 of AllCerts.zip.
# Update this after each DoD bundle refresh:
#   sha256sum /tmp/cac_for_linux_distros_staging/AllCerts.zip
# Set to "" to warn-only without a specific expected hash.
# See KNOWN_ISSUES.md #P9.
KNOWN_CERT_SHA256=""

CERT_FILES=()

download_certs() {
    log_section "Certificate Download"
    mkdir -p "$DWNLD_DIR"
    log_info "Downloading DoD certificate bundle from: $CERT_URL"
    if ! log_cmd wget -q --show-progress -P "$DWNLD_DIR" "$CERT_URL"; then
        log_error "Download failed. Check network connectivity and that militarycac.com is reachable."
        cleanup_certs
        exit 1
    fi
    log_success "Downloaded: $DWNLD_DIR/$BUNDLE_NAME"
}

validate_cert_bundle() {
    log_info "Validating certificate bundle integrity..."
    local actual_sha
    actual_sha="$(sha256sum "$DWNLD_DIR/$BUNDLE_NAME" | cut -d' ' -f1)"
    echo "STATE:cert_bundle_sha256=${actual_sha}"
    log_info "SHA-256: $actual_sha"

    if [[ -n "$KNOWN_CERT_SHA256" ]]; then
        if [[ "$actual_sha" == "$KNOWN_CERT_SHA256" ]]; then
            log_success "Checksum verified."
        else
            log_warn "Checksum mismatch!"
            log_warn "  Expected: $KNOWN_CERT_SHA256"
            log_warn "  Actual:   $actual_sha"
            log_warn "DoD may have refreshed the bundle. Verify the download is legitimate,"
            log_warn "then update KNOWN_CERT_SHA256 in lib/certs.sh. See KNOWN_ISSUES.md #P9."
        fi
    else
        log_warn "No baseline checksum configured — skipping integrity check."
        log_warn "Populate KNOWN_CERT_SHA256 in lib/certs.sh after first successful download."
    fi
}

extract_certs() {
    log_info "Extracting certificate bundle..."
    local dest="$DWNLD_DIR/$CERT_DIR_NAME"
    mkdir -p "$dest"
    if ! log_cmd unzip -q "$DWNLD_DIR/$BUNDLE_NAME" -d "$dest"; then
        log_error "Extraction failed. The bundle may be corrupt — try re-downloading."
        cleanup_certs
        exit 1
    fi

    # mapfile handles filenames with spaces safely
    mapfile -t CERT_FILES < <(find "$dest" -name "*.cer" -type f)
    local count="${#CERT_FILES[@]}"
    if [[ $count -eq 0 ]]; then
        log_error "No .cer files found after extraction. Bundle may be empty or malformed."
        cleanup_certs
        exit 1
    fi
    log_success "Extracted $count certificate files."
}

cleanup_certs() {
    # Remove the PID-unique staging directory. Called on exit (success or failure).
    if [[ -d "$DWNLD_DIR" ]]; then
        log_info "Cleaning up staging directory: $DWNLD_DIR"
        if rm -rf "$DWNLD_DIR"; then
            log_success "Staging directory removed."
        else
            log_warn "Could not remove $DWNLD_DIR — remove manually if needed."
        fi
    fi
}
