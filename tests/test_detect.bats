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
