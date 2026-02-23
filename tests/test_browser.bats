#!/usr/bin/env bats
# tests/test_browser.bats — Unit tests for lib/browser.sh

load 'helpers/bats_helper'

setup() {
    _setup_test_env
    _source_lib "log"
    _source_lib "detect"
    _source_lib "browser"
    _use_mocks
    _setup_mock_logs
    # Reset globals
    NSS_DATABASES=()
    FF_FOUND=false
    CHROMIUM_ANY_FOUND=false
    # Create fake home directory structure
    mkdir -p "$REAL_HOME"
}

teardown() {
    rm -f "$_CAC_LOG_FILE"
    rm -rf "$REAL_HOME"
}

@test "check_browsers_closed passes when no browser processes are running" {
    # pgrep mock returns empty output (exit 1 = no match)
    local pgrep_dir="$BATS_TMPDIR/pgrep_dir"
    mkdir -p "$pgrep_dir"
    printf '#!/bin/bash\nexit 1\n' > "$pgrep_dir/pgrep"
    chmod +x "$pgrep_dir/pgrep"
    PATH="$pgrep_dir:$PATH" run check_browsers_closed
    [ "$status" -eq 0 ]
}

@test "check_browsers_closed exits with E_BROWSER when browser is running" {
    local pgrep_dir="$BATS_TMPDIR/pgrep_dir2"
    mkdir -p "$pgrep_dir"
    printf '#!/bin/bash\necho "12345"\nexit 0\n' > "$pgrep_dir/pgrep"
    chmod +x "$pgrep_dir/pgrep"
    PATH="$pgrep_dir:$PATH" run check_browsers_closed
    [ "$status" -eq 87 ]
}

@test "check_for_firefox sets FF_FOUND=true when firefox is on PATH" {
    local ff_dir="$BATS_TMPDIR/ff_dir"
    mkdir -p "$ff_dir"
    # Create cert9.db so _ensure_firefox_profile succeeds immediately
    mkdir -p "$REAL_HOME/.config/mozilla/firefox/default.default"
    touch "$REAL_HOME/.config/mozilla/firefox/default.default/cert9.db"
    printf '#!/bin/bash\nexit 0\n' > "$ff_dir/firefox"
    chmod +x "$ff_dir/firefox"
    PATH="$ff_dir:$PATH" check_for_firefox
    [[ "$FF_FOUND" == "true" ]]
}

@test "check_for_firefox leaves FF_FOUND=false when firefox absent" {
    local no_ff_dir="$BATS_TMPDIR/no_firefox_$$"
    mkdir -p "$no_ff_dir"
    PATH="$no_ff_dir" check_for_firefox
    [[ "$FF_FOUND" == "false" ]]
}

@test "check_for_chromium_browsers sets CHROMIUM_ANY_FOUND=true when chromium present" {
    local cr_dir="$BATS_TMPDIR/cr_dir"
    mkdir -p "$cr_dir"
    printf '#!/bin/bash\nexit 0\n' > "$cr_dir/chromium"
    chmod +x "$cr_dir/chromium"
    PATH="$cr_dir:$PATH" check_for_chromium_browsers
    [[ "$CHROMIUM_ANY_FOUND" == "true" ]]
}

@test "discover_databases finds Firefox NSS database when profile exists" {
    # Create the Firefox profile directory with cert9.db
    local ff_profile="$REAL_HOME/.config/mozilla/firefox/abc.default"
    mkdir -p "$ff_profile"
    touch "$ff_profile/cert9.db"
    # Set FF_FOUND so discover_databases doesn't need check_for_firefox to run
    FF_FOUND=true
    CHROMIUM_ANY_FOUND=false
    # Override E_DATABASE to avoid exit on missing certutil
    local pgrep_dir="$BATS_TMPDIR/pgrep_pass"
    mkdir -p "$pgrep_dir"
    printf '#!/bin/bash\nexit 1\n' > "$pgrep_dir/pgrep"
    chmod +x "$pgrep_dir/pgrep"
    local ff_bin="$BATS_TMPDIR/ff_bin"
    mkdir -p "$ff_bin"
    printf '#!/bin/bash\nexit 0\n' > "$ff_bin/firefox"
    chmod +x "$ff_bin/firefox"
    PATH="$pgrep_dir:$ff_bin:$PATH" discover_databases
    [[ "${NSS_DATABASES[*]}" == *"$ff_profile"* ]]
}

@test "_ensure_nssdb creates NSS database at REAL_HOME/.pki/nssdb" {
    MOCK_CERTUTIL_EXIT=0 _ensure_nssdb
    [[ -d "$REAL_HOME/.pki/nssdb" ]]
}
