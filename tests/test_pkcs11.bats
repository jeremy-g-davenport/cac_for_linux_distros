#!/usr/bin/env bats
# tests/test_pkcs11.bats — Unit tests for lib/pkcs11.sh

load 'helpers/bats_helper'

setup() {
    _setup_test_env
    _source_lib "log"
    _source_lib "detect"
    _source_lib "pkcs11"
    _use_mocks
    _setup_mock_logs
    export TEST_DB="$BATS_TMPDIR/nssdb"
    mkdir -p "$TEST_DB"
    NSS_DATABASES=("$TEST_DB")
}

teardown() {
    rm -f "$_CAC_LOG_FILE"
    rm -rf "$TEST_DB"
}

@test "register_pkcs11_in_db calls modutil -add when module not yet registered" {
    # -list returns empty (not registered)
    MOCK_MODUTIL_LIST_OUTPUT="" register_pkcs11_in_db "$TEST_DB"
    grep -q "\-add" "$MOCK_MODUTIL_LOG"
}

@test "register_pkcs11_in_db skips when module already registered" {
    # -list output shows opensc-pkcs11 already present
    MOCK_MODUTIL_LIST_OUTPUT="opensc-pkcs11" register_pkcs11_in_db "$TEST_DB"
    ! grep -q "\-add" "$MOCK_MODUTIL_LOG" 2>/dev/null
    true
}

@test "register_pkcs11_in_db emits ACTION and STATE lines on success" {
    MOCK_MODUTIL_LIST_OUTPUT=""
    MOCK_MODUTIL_EXIT=0
    output="$(MOCK_MODUTIL_LIST_OUTPUT="" register_pkcs11_in_db "$TEST_DB")"
    [[ "$output" == *"ACTION:pkcs11_register"* ]]
    [[ "$output" == *"STATE:pkcs11_registered_in+="* ]]
}

@test "register_pkcs11_all exits when OPENSC_PKCS11_LIB does not exist" {
    OPENSC_PKCS11_LIB="/nonexistent/opensc-pkcs11.so"
    run register_pkcs11_all
    [ "$status" -ne 0 ]
}

@test "register_pkcs11_all iterates over all NSS_DATABASES" {
    local db2="$BATS_TMPDIR/nssdb2"
    mkdir -p "$db2"
    NSS_DATABASES=("$TEST_DB" "$db2")
    # Create a real file so OPENSC_PKCS11_LIB existence check passes
    OPENSC_PKCS11_LIB="$(mktemp)"
    MOCK_MODUTIL_LIST_OUTPUT="" register_pkcs11_all
    rm -f "$OPENSC_PKCS11_LIB"
    # modutil should have been called for each database
    local call_count
    call_count="$(grep -c "\-dbdir" "$MOCK_MODUTIL_LOG" 2>/dev/null || echo 0)"
    [ "$call_count" -ge 2 ]
}

@test "unregister_pkcs11_all calls modutil -delete for each registered database" {
    printf '{"pkcs11_registered_in":["%s"]}\n' "$TEST_DB" > "$STATE_FILE"
    # -list shows CAC Module is present
    MOCK_MODUTIL_LIST_OUTPUT="CAC Module" unregister_pkcs11_all
    grep -q "\-delete" "$MOCK_MODUTIL_LOG"
}

@test "unregister_pkcs11_all is idempotent when module already removed" {
    printf '{"pkcs11_registered_in":["%s"]}\n' "$TEST_DB" > "$STATE_FILE"
    # -list returns empty (module already gone)
    MOCK_MODUTIL_LIST_OUTPUT="" unregister_pkcs11_all
    ! grep -q "\-delete" "$MOCK_MODUTIL_LOG" 2>/dev/null
    true
}
