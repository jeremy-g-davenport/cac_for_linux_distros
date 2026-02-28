#!/usr/bin/env bats
# tests/test_detect.bats — Unit tests for lib/detect.sh

load 'helpers/bats_helper'

setup() {
    _setup_test_env
    _source_lib "log"
    _source_lib "detect"
}

teardown() {
    rm -f "$_CAC_LOG_FILE"
}

@test "detect_root exits with E_NOTROOT when not running as root" {
    if [[ $(id -u) -eq 0 ]]; then
        skip "running as root — cannot test non-root exit"
    fi
    run detect_root
    [ "$status" -eq 86 ]
}

@test "detect_real_user succeeds with REAL_USER and REAL_HOME set" {
    run detect_real_user
    [ "$status" -eq 0 ]
}

@test "detect_real_user exits with E_NOTROOT when REAL_USER is empty" {
    REAL_USER="" run detect_real_user
    [ "$status" -eq 86 ]
}

@test "validate_env succeeds when all required vars are set" {
    run validate_env
    [ "$status" -eq 0 ]
}

@test "validate_env exits with E_CONFIG when a required var is missing" {
    PKCS11_LIB="" run validate_env
    [ "$status" -eq 92 ]
}

@test "detect_to_json emits valid JSON with arch, user, pkcs11_lib keys" {
    output="$(detect_to_json)"
    [[ "$output" == *'"arch"'* ]]
    [[ "$output" == *'"user"'* ]]
    [[ "$output" == *'"pkcs11_lib"'* ]]
}

@test "_state_read_list reads array from STATE_FILE" {
    printf '{"nss_databases":["/home/user/.pki/nssdb","/home/user/.mozilla/firefox/abc"]}\n' \
        > "$STATE_FILE"
    local items
    mapfile -t items < <(_state_read_list "nss_databases")
    [ "${#items[@]}" -eq 2 ]
    [[ "${items[0]}" == "/home/user/.pki/nssdb" ]]
}

@test "_state_read_list returns nothing when STATE_FILE is missing" {
    rm -f "$STATE_FILE"
    local items
    mapfile -t items < <(_state_read_list "nss_databases")
    [ "${#items[@]}" -eq 0 ]
}

@test "detect_required_tools succeeds even when certutil is absent from PATH" {
    # certutil/modutil are installed by the packages phase, not a preflight requirement.
    # Removing them from PATH must result in a warning, not a fatal exit.
    local no_cert_dir="$BATS_TMPDIR/no_certutil"
    mkdir -p "$no_cert_dir"
    # Build a PATH that has all required system tools except certutil/modutil
    local filtered_path
    filtered_path="$(echo "$PATH" | tr ':' '\n' | grep -v "mocks" | tr '\n' ':' | sed 's/:$//')"
    PATH="$no_cert_dir:$filtered_path" run detect_required_tools
    [ "$status" -eq 0 ]
}

@test "detect_selinux is a no-op when getenforce is absent from PATH" {
    local no_selinux_dir="$BATS_TMPDIR/no_selinux"
    mkdir -p "$no_selinux_dir"
    PATH="$no_selinux_dir" run detect_selinux
    [ "$status" -eq 0 ]
}

@test "detect_selinux logs warning when SELinux is Enforcing" {
    local mock_dir="$BATS_TMPDIR/selinux_mock"
    mkdir -p "$mock_dir"
    printf '#!/bin/bash\necho "Enforcing"\n' > "$mock_dir/getenforce"
    chmod +x "$mock_dir/getenforce"
    PATH="$mock_dir:$PATH" run detect_selinux
    [ "$status" -eq 0 ]
    [[ "$output" == *"SELinux is Enforcing"* ]]
}

@test "detect_selinux logs info when SELinux is Permissive" {
    local mock_dir="$BATS_TMPDIR/selinux_permissive"
    mkdir -p "$mock_dir"
    printf '#!/bin/bash\necho "Permissive"\n' > "$mock_dir/getenforce"
    chmod +x "$mock_dir/getenforce"
    PATH="$mock_dir:$PATH" run detect_selinux
    [ "$status" -eq 0 ]
    [[ "$output" == *"Permissive"* ]]
}
