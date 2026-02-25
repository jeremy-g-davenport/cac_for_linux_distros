#!/bin/bash
# lib/browser.sh — Browser detection and NSS database discovery
#
# Provides: check_browsers_closed, check_for_firefox, check_for_chromium_browsers,
#           discover_databases
#
# NSS OWNERSHIP RULE (critical, enforced without exception):
# All certutil and modutil operations against user-owned NSS databases MUST be
# run as $REAL_USER via `sudo -H -u "$REAL_USER"`, never directly as root.
# Root-owned files in a user's NSS database are unreadable by the browser
# process, silently breaking CAC authentication. See KNOWN_ISSUES.md #P6.
#
# CachyOS note: Firefox stores profiles in ~/.config/mozilla/firefox/, not
# ~/.mozilla/firefox/. Both paths are searched. See KNOWN_ISSUES.md #P5.
#
# No set -euo pipefail — inherited from bash/install.sh or bash/uninstall.sh.

NSS_DATABASES=()
FF_FOUND=false
CHROMIUM_ANY_FOUND=false

# Phases that run after the import phase (pkcs11, verify) receive NSS_DB_PATHS
# injected by the Python orchestrator with the databases discovered during import.
# Convert it to the NSS_DATABASES array so those phases can operate on the
# same databases without re-running discover_databases (which has side-effects
# like headless Firefox launch and browser-closed checks).
if [[ ${#NSS_DATABASES[@]} -eq 0 ]] && [[ -n "${NSS_DB_PATHS:-}" ]]; then
    IFS=':' read -ra NSS_DATABASES <<< "$NSS_DB_PATHS"
fi

check_browsers_closed() {
    # Browsers must be closed before NSS database modifications.
    # Writing cert9.db or pkcs11.txt while a browser holds the file open
    # produces silent corruption or no-ops. Addresses KNOWN_ISSUES.md #P7.
    local running_browsers
    running_browsers="$(pgrep -x -E "firefox|chromium|google-chrome|microsoft-edge|brave" 2>/dev/null || true)"
    if [[ -n "$running_browsers" ]]; then
        log_error "Browser processes are running. Close all browsers before running this script."
        log_error "Detected PIDs: $running_browsers"
        log_error "Run: pkill firefox chromium google-chrome microsoft-edge brave"
        exit "$E_BROWSER"
    fi
    log_success "No browser processes detected."
}

_ensure_firefox_profile() {
    # Locate cert9.db in the Firefox profile directory.
    # If missing, launch Firefox headlessly and poll every 0.5s for up to 30s.
    # Replaces unreliable `sleep 3` from source script. Addresses KNOWN_ISSUES.md #P10.
    local ff_db
    ff_db="$(find "$REAL_HOME/.config/mozilla/firefox" \
                  "$REAL_HOME/.mozilla/firefox" \
                  -name cert9.db 2>/dev/null | grep -v Trash | head -1 || true)"

    if [[ -z "$ff_db" ]]; then
        log_info "Initializing Firefox profile (headless)..."
        sudo -H -u "$REAL_USER" firefox --headless --first-startup > /dev/null 2>&1 &
        local ff_pid=$!
        local waited=0
        while [[ $waited -lt 30 ]]; do
            ff_db="$(find "$REAL_HOME/.config/mozilla/firefox" \
                          "$REAL_HOME/.mozilla/firefox" \
                          -name cert9.db 2>/dev/null | grep -v Trash | head -1 || true)"
            [[ -n "$ff_db" ]] && break
            sleep 0.5
            (( ++waited ))
        done
        kill "$ff_pid" 2>/dev/null || true
        if [[ -z "$ff_db" ]]; then
            log_warn "Firefox profile not created after 30s."
            log_warn "Open Firefox manually, close it, then re-run this script."
            return 1
        fi
    fi
    log_success "Firefox profile found: $(dirname "$ff_db")"
    return 0
}

check_for_firefox() {
    log_info "Checking for Firefox..."
    if command -v firefox > /dev/null 2>&1; then
        FF_FOUND=true
        log_success "Firefox: $(command -v firefox)"
        _ensure_firefox_profile
    else
        log_info "Firefox not installed."
    fi
}

check_for_chromium_browsers() {
    log_info "Checking for Chromium-based browsers..."
    local found_count=0
    local browser
    for browser in google-chrome chromium microsoft-edge-stable brave; do
        if command -v "$browser" > /dev/null 2>&1; then
            log_success "Found: $browser"
            (( ++found_count ))
        fi
    done
    if [[ $found_count -gt 0 ]]; then
        CHROMIUM_ANY_FOUND=true
    fi
}

_ensure_nssdb() {
    # Create the shared Chromium NSS database if it doesn't exist.
    # MUST run certutil as $REAL_USER — never root (NSS ownership rule).
    local nssdb="$REAL_HOME/.pki/nssdb"
    if [[ ! -d "$nssdb" ]]; then
        log_info "Creating shared Chromium NSS database at: $nssdb"
        sudo -H -u "$REAL_USER" mkdir -p "$nssdb"
        local _nssdb_init_out _nssdb_init_rc=0
        _nssdb_init_out=$(sudo -H -u "$REAL_USER" certutil -d "sql:$nssdb" -N --empty-password 2>&1) \
            || _nssdb_init_rc=$?
        printf '%s\n' "$_nssdb_init_out" >> "$_CAC_LOG_FILE"
        if [[ $_nssdb_init_rc -ne 0 ]]; then
            log_error "Failed to initialize NSS database at $nssdb"
            return 1
        fi
        log_success "NSS database created: $nssdb"
    else
        log_info "NSS database exists: $nssdb"
    fi
}

discover_databases() {
    log_section "Browser and Database Discovery"
    check_browsers_closed
    check_for_firefox
    check_for_chromium_browsers

    if [[ "$FF_FOUND" == false ]] && [[ "$CHROMIUM_ANY_FOUND" == false ]]; then
        log_error "No supported browsers found."
        log_error "Install Firefox, Chromium, Google Chrome, Microsoft Edge, or Brave."
        exit "$E_BROWSER"
    fi

    NSS_DATABASES=()

    # Firefox NSS databases — search both CachyOS and standard profile roots
    local ff_db db_dir
    while IFS= read -r ff_db; do
        db_dir="$(dirname "$ff_db")"
        log_info "Firefox NSS database: $db_dir"
        NSS_DATABASES+=("$db_dir")
    done < <(find "$REAL_HOME/.config/mozilla/firefox" \
                  "$REAL_HOME/.mozilla/firefox" \
                  -name cert9.db 2>/dev/null | grep -v Trash || true)

    # Chromium-based browsers share a single NSS database
    if [[ "$CHROMIUM_ANY_FOUND" == true ]]; then
        _ensure_nssdb
        if [[ -d "$REAL_HOME/.pki/nssdb" ]]; then
            log_info "Chromium NSS database: $REAL_HOME/.pki/nssdb"
            NSS_DATABASES+=("$REAL_HOME/.pki/nssdb")
        fi
    fi

    if [[ ${#NSS_DATABASES[@]} -eq 0 ]]; then
        log_error "No NSS databases found."
        log_error "Open each installed browser once, close it, then re-run."
        exit "$E_DATABASE"
    fi

    # Emit colon-separated list for Python state tracking
    local IFS=':'
    echo "STATE:nss_databases=${NSS_DATABASES[*]}"

    log_success "Discovered ${#NSS_DATABASES[@]} NSS database(s)."
}
