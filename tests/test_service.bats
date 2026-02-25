#!/usr/bin/env bats
# tests/test_service.bats — Unit tests for lib/service.sh

load 'helpers/bats_helper'

setup() {
    _setup_test_env
    _source_lib "log"
    _source_lib "service"
    _use_mocks
    _setup_mock_logs
}

teardown() {
    rm -f "$_CAC_LOG_FILE"
}

@test "record_pcscd_state emits STATE:pcscd_was_active_before=false when inactive" {
    export MOCK_SYSTEMCTL_ACTIVE=1  # non-zero = not active
    output="$(record_pcscd_state)"
    [[ "$output" == *"STATE:pcscd_was_active_before=false"* ]]
}

@test "record_pcscd_state emits STATE:pcscd_was_active_before=true when active" {
    MOCK_SYSTEMCTL_ACTIVE=0  # zero = active
    output="$(record_pcscd_state)"
    [[ "$output" == *"STATE:pcscd_was_active_before=true"* ]]
}

@test "enable_pcscd calls systemctl enable and start for socket and service" {
    enable_pcscd
    grep -q "systemctl enable pcscd.socket" "$MOCK_SYSTEMCTL_LOG"
    grep -q "systemctl start pcscd.socket" "$MOCK_SYSTEMCTL_LOG"
    grep -q "systemctl start pcscd.service" "$MOCK_SYSTEMCTL_LOG"
}

@test "enable_pcscd triggers udev USB rules for card reader access" {
    # pacman's post-hook reloads udev rules but never triggers existing devices.
    # enable_pcscd must run udevadm trigger so connected readers get updated
    # device-node permissions before pcscd.service starts. See Issue #5e.
    enable_pcscd
    grep -q "udevadm trigger" "$MOCK_UDEVADM_LOG"
}

@test "enable_pcscd emits ACTION lines for service_enable and service_start" {
    output="$(enable_pcscd)"
    [[ "$output" == *"ACTION:service_enable"* ]]
    [[ "$output" == *"ACTION:service_start"* ]]
}

@test "verify_pcscd_service returns 0 when systemctl is-active succeeds" {
    MOCK_SYSTEMCTL_ACTIVE=0 run verify_pcscd_service
    [ "$status" -eq 0 ]
}

@test "verify_pcscd_service returns non-zero when pcscd is not active" {
    MOCK_SYSTEMCTL_ACTIVE=3 run verify_pcscd_service
    [ "$status" -ne 0 ]
}

@test "disable_pcscd calls systemctl stop and disable" {
    disable_pcscd
    grep -q "systemctl stop" "$MOCK_SYSTEMCTL_LOG"
    grep -q "systemctl disable" "$MOCK_SYSTEMCTL_LOG"
}
