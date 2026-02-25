#!/usr/bin/env bats
# tests/test_verify.bats — Unit tests for lib/verify.sh

load 'helpers/bats_helper'

setup() {
    _setup_test_env
    _source_lib "log"
    _source_lib "detect"
    _source_lib "service"
    _source_lib "verify"
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

@test "verify_pcscd returns 0 when pcscd.socket is active" {
    MOCK_SYSTEMCTL_ACTIVE=0 run verify_pcscd
    [ "$status" -eq 0 ]
}

@test "verify_pcscd returns non-zero when pcscd.socket is inactive" {
    MOCK_SYSTEMCTL_ACTIVE=3 run verify_pcscd
    [ "$status" -ne 0 ]
}

@test "verify_pkcs11_registered returns 0 when module is registered in all databases" {
    MOCK_MODUTIL_LIST_OUTPUT="opensc-pkcs11" run verify_pkcs11_registered
    [ "$status" -eq 0 ]
}

@test "verify_pkcs11_registered returns non-zero when module is missing from a database" {
    MOCK_MODUTIL_LIST_OUTPUT="" run verify_pkcs11_registered
    [ "$status" -ne 0 ]
}

@test "verify_certificates_imported logs cert count per database" {
    # 15 lines of output from certutil -L
    MOCK_CERTUTIL_LIST_OUTPUT="$(printf 'cert%d\n' {1..15})"
    MOCK_CERTUTIL_LIST_OUTPUT="$MOCK_CERTUTIL_LIST_OUTPUT" verify_certificates_imported
    grep -q "\[OK\]" "$_CAC_LOG_FILE"
}

@test "verify_card_reader logs when opensc-tool output is empty" {
    MOCK_OPENSC_TOOL_OUTPUT="" verify_card_reader
    grep -q "\[INFO\]" "$_CAC_LOG_FILE"
}

@test "verify_card_objects reports objects when Certificate found in output" {
    MOCK_PKCS11_TOOL_OUTPUT="Certificate: My CAC Cert" verify_card_objects
    grep -q "\[OK\]" "$_CAC_LOG_FILE"
}

@test "verify_card_objects warns when no CAC is inserted" {
    MOCK_PKCS11_TOOL_OUTPUT="no token" verify_card_objects
    grep -q "\[WARN\]" "$_CAC_LOG_FILE"
}

@test "run_uninstall_verification reports clean state when no issues" {
    # modutil -list returns empty (no CAC Module) and systemctl is-active returns non-zero
    MOCK_MODUTIL_LIST_OUTPUT="" MOCK_SYSTEMCTL_ACTIVE=3 run_uninstall_verification
    grep -q "passed" "$_CAC_LOG_FILE"
}

@test "verify_pkcs11_registered returns non-zero when NSS_DATABASES is empty" {
    NSS_DATABASES=()
    run verify_pkcs11_registered
    [ "$status" -ne 0 ]
}
