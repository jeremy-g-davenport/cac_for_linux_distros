#!/usr/bin/env bats
# tests/test_aur.bats — Unit tests for lib/aur.sh

load 'helpers/bats_helper'

setup() {
    _setup_test_env
    _source_lib "log"
    _source_lib "aur"
    _use_mocks
    _setup_mock_logs
}

teardown() {
    rm -f "$_CAC_LOG_FILE"
}

@test "detect_aur_helper sets _AUR_HELPER to paru when paru is present" {
    local paru_dir="$BATS_TMPDIR/paru_bin"
    mkdir -p "$paru_dir"
    printf '#!/bin/bash\nexit 0\n' > "$paru_dir/paru"
    chmod +x "$paru_dir/paru"
    PATH="$paru_dir:$PATH" detect_aur_helper
    [[ "$_AUR_HELPER" == "paru" ]]
}

@test "detect_aur_helper falls back to yay when paru is absent" {
    local yay_dir="$BATS_TMPDIR/yay_bin"
    mkdir -p "$yay_dir"
    printf '#!/bin/bash\nexit 0\n' > "$yay_dir/yay"
    chmod +x "$yay_dir/yay"
    # paru is not in PATH; only yay is
    PATH="$yay_dir:$(echo "$PATH" | tr ':' '\n' | grep -v paru | tr '\n' ':' | sed 's/:$//')" \
        detect_aur_helper
    [[ "$_AUR_HELPER" == "yay" ]]
}

@test "detect_aur_helper sets _AUR_HELPER to empty when no AUR helper found" {
    # PATH has mocks/ but no paru or yay executables
    detect_aur_helper
    [[ -z "$_AUR_HELPER" ]]
}

@test "aur_install returns 1 gracefully when _AUR_HELPER is empty" {
    _AUR_HELPER=""
    run aur_install "some-aur-package"
    [ "$status" -eq 1 ]
}

@test "aur_install calls the AUR helper as REAL_USER via sudo" {
    local paru_dir="$BATS_TMPDIR/paru_bin2"
    mkdir -p "$paru_dir"
    printf '#!/bin/bash\necho "paru $*" >> "%s/paru_calls.log"\nexit 0\n' \
        "$BATS_TMPDIR" > "$paru_dir/paru"
    chmod +x "$paru_dir/paru"
    PATH="$paru_dir:$PATH" _AUR_HELPER="paru" aur_install "test-pkg"
    grep -q "paru -S --noconfirm test-pkg" "$BATS_TMPDIR/paru_calls.log"
}
