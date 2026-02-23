#!/usr/bin/env bats
# tests/test_certs.bats — Unit tests for lib/certs.sh

load 'helpers/bats_helper'

setup() {
    _setup_test_env
    _source_lib "log"
    _source_lib "certs"
    _use_mocks
    _setup_mock_logs
    # Override DWNLD_DIR to a writable temp location
    DWNLD_DIR="$BATS_TMPDIR/cac_test_$$"
}

teardown() {
    rm -f "$_CAC_LOG_FILE"
    rm -rf "$BATS_TMPDIR/cac_test_$$"
}

@test "download_certs creates AllCerts.zip in DWNLD_DIR" {
    MOCK_WGET_EXIT=0 download_certs
    [[ -f "$DWNLD_DIR/AllCerts.zip" ]]
}

@test "download_certs exits non-zero when wget fails" {
    MOCK_WGET_EXIT=1 run download_certs
    [ "$status" -ne 0 ]
}

@test "validate_cert_bundle emits STATE:cert_bundle_sha256 line" {
    mkdir -p "$DWNLD_DIR"
    touch "$DWNLD_DIR/AllCerts.zip"
    local expected_hash="abcd1234"
    MOCK_SHA256="$expected_hash" output="$(validate_cert_bundle)"
    [[ "$output" == *"STATE:cert_bundle_sha256=${expected_hash}"* ]]
}

@test "validate_cert_bundle warns on checksum mismatch" {
    mkdir -p "$DWNLD_DIR"
    touch "$DWNLD_DIR/AllCerts.zip"
    KNOWN_CERT_SHA256="expected_hash_value"
    MOCK_SHA256="different_hash_value" validate_cert_bundle
    grep -q "\[WARN\]" "$_CAC_LOG_FILE"
}

@test "extract_certs populates CERT_FILES array" {
    mkdir -p "$DWNLD_DIR"
    touch "$DWNLD_DIR/AllCerts.zip"
    MOCK_UNZIP_EXIT=0 extract_certs
    [ "${#CERT_FILES[@]}" -gt 0 ]
}

@test "extract_certs exits when zip extraction fails" {
    mkdir -p "$DWNLD_DIR"
    touch "$DWNLD_DIR/AllCerts.zip"
    MOCK_UNZIP_EXIT=1 run extract_certs
    [ "$status" -ne 0 ]
}

@test "cleanup_certs removes the staging directory" {
    mkdir -p "$DWNLD_DIR"
    cleanup_certs
    [[ ! -d "$DWNLD_DIR" ]]
}
