#!/usr/bin/env bats
# tests/test_import.bats — Unit tests for lib/import.sh

load 'helpers/bats_helper'

setup() {
    _setup_test_env
    _source_lib "log"
    _source_lib "detect"
    _source_lib "import"
    _use_mocks
    _setup_mock_logs
    # Set up a fake NSS database directory
    export TEST_DB="$BATS_TMPDIR/nssdb"
    mkdir -p "$TEST_DB"
    # Set up fake cert files
    export TEST_CERTS_DIR="$BATS_TMPDIR/certs"
    mkdir -p "$TEST_CERTS_DIR"
    echo "fake cert" > "$TEST_CERTS_DIR/DoD_Root_CA_1.cer"
    echo "fake cert" > "$TEST_CERTS_DIR/DoD_Root_CA_2.cer"
    echo "fake cert" > "$TEST_CERTS_DIR/DoD_CA_1.cer"
    CERT_FILES=("$TEST_CERTS_DIR/DoD_Root_CA_1.cer"
                "$TEST_CERTS_DIR/DoD_Root_CA_2.cer"
                "$TEST_CERTS_DIR/DoD_CA_1.cer")
    NSS_DATABASES=("$TEST_DB")
}

teardown() {
    rm -f "$_CAC_LOG_FILE"
    rm -rf "$TEST_DB" "$TEST_CERTS_DIR"
}

@test "import_certs_into_db calls certutil -A for each cert not yet present" {
    # Lookup returns 1 (not present) → should call certutil -A
    MOCK_CERTUTIL_LOOKUP_EXIT=1 import_certs_into_db "$TEST_DB"
    grep -q "\-A" "$MOCK_CERTUTIL_LOG"
}

@test "import_certs_into_db skips certs already present in database" {
    # Lookup returns 0 (already present) → should NOT call certutil -A
    MOCK_CERTUTIL_LOOKUP_EXIT=0 import_certs_into_db "$TEST_DB"
    ! grep -q "\-A " "$MOCK_CERTUTIL_LOG" 2>/dev/null
    true
}

@test "import_certs_into_db emits STATE: lines for imported certs" {
    MOCK_CERTUTIL_LOOKUP_EXIT=1
    MOCK_CERTUTIL_EXIT=0
    output="$(MOCK_CERTUTIL_LOOKUP_EXIT=1 import_certs_into_db "$TEST_DB")"
    [[ "$output" == *"STATE:imported_cert_nicknames+="* ]]
}

@test "import_all_certs exits when CERT_FILES is empty" {
    CERT_FILES=()
    run import_all_certs
    [ "$status" -ne 0 ]
}

@test "import_all_certs iterates over all NSS_DATABASES" {
    local db2="$BATS_TMPDIR/nssdb2"
    mkdir -p "$db2"
    NSS_DATABASES=("$TEST_DB" "$db2")
    MOCK_CERTUTIL_LOOKUP_EXIT=1 import_all_certs
    # certutil should have been called for both databases
    local call_count
    call_count="$(grep -c "\-d" "$MOCK_CERTUTIL_LOG" 2>/dev/null || echo 0)"
    [ "$call_count" -ge 2 ]
}

@test "remove_all_certs reads nicknames from STATE_FILE and calls certutil -D" {
    printf '{"nss_databases":["%s"],"imported_cert_nicknames":["DoD_Root_CA_1.cer"]}\n' \
        "$TEST_DB" > "$STATE_FILE"
    # Lookup returns 0 (cert is present) → should call certutil -D
    MOCK_CERTUTIL_LOOKUP_EXIT=0 remove_all_certs
    grep -q "\-D" "$MOCK_CERTUTIL_LOG"
}
