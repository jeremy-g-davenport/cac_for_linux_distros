#!/usr/bin/env bats
# tests/test_log.bats — Unit tests for lib/log.sh

load 'helpers/bats_helper'

setup() {
    _setup_test_env
    _source_lib "log"
}

teardown() {
    rm -f "$_CAC_LOG_FILE"
}

@test "log_init creates log file at expected path" {
    if [[ $(id -u) -ne 0 ]] && [[ ! -w /var/log ]]; then
        skip "/var/log not writable — run as root or in archlinux:latest container"
    fi
    local prev="$_CAC_LOG_FILE"
    unset _CAC_LOG_FILE
    log_init
    [[ -f "$_CAC_LOG_FILE" ]]
    rm -f "$_CAC_LOG_FILE"
    _CAC_LOG_FILE="$prev"
}

@test "log_info writes message to log file without ANSI codes" {
    log_info "hello world"
    grep -q "\[INFO\]  hello world" "$_CAC_LOG_FILE"
}

@test "log_cmd returns 0 for a succeeding command" {
    run log_cmd true
    [ "$status" -eq 0 ]
}

@test "log_cmd returns 1 for a failing command" {
    run log_cmd false
    [ "$status" -eq 1 ]
}

@test "log_cmd captures exit code in log file" {
    log_cmd false >> /dev/null 2>&1 || true
    grep -q "\[EXIT\]  1" "$_CAC_LOG_FILE"
}

@test "log_cmd expands multi-token commands correctly" {
    run log_cmd test -f /nonexistent/path/xyz
    [ "$status" -eq 1 ]
}
