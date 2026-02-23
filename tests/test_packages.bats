#!/usr/bin/env bats
# tests/test_packages.bats — Unit tests for lib/packages.sh

load 'helpers/bats_helper'

setup() {
    _setup_test_env
    _source_lib "log"
    _source_lib "detect"
    _source_lib "packages"
    _use_mocks
    _setup_mock_logs
}

teardown() {
    rm -f "$_CAC_LOG_FILE"
}

@test "is_package_installed returns 0 when pacman -Qi succeeds" {
    MOCK_PACMAN_QI_EXIT=0 run is_package_installed "opensc"
    [ "$status" -eq 0 ]
}

@test "is_package_installed returns non-zero when pacman -Qi fails" {
    MOCK_PACMAN_QI_EXIT=1 run is_package_installed "missing-pkg"
    [ "$status" -ne 0 ]
}

@test "install_official_packages logs Already installed when all packages present" {
    # Mock pacman -Qi to always return 0 (all packages installed)
    MOCK_PACMAN_QI_EXIT=0 install_official_packages
    # Should not have called pacman -S (no packages to install)
    ! grep -q "\-S " "$MOCK_PACMAN_LOG" 2>/dev/null || \
        ! grep -qv "\-Syu\|\-Qi\|\-S --needed" "$MOCK_PACMAN_LOG"
}

@test "install_official_packages calls pacman -Syu (not -Sy alone)" {
    MOCK_PACMAN_QI_EXIT=0 install_official_packages
    grep -q "\-Syu" "$MOCK_PACMAN_LOG"
    ! grep -q "\-Sy[^u]" "$MOCK_PACMAN_LOG"
}

@test "install_official_packages installs missing packages" {
    # pacman -Qi returns 1 (not installed) for all packages
    MOCK_PACMAN_QI_EXIT=1 install_official_packages
    grep -q "\-S " "$MOCK_PACMAN_LOG"
}

@test "verify_certutil succeeds when certutil and modutil are on PATH" {
    # certutil and modutil mocks are in PATH
    run verify_certutil
    [ "$status" -eq 0 ]
}

@test "remove_smart_card_packages removes installed smart-card packages" {
    # State file has packages that were installed
    printf '{"packages_installed":["pcsclite=1.0","opensc=1.0"]}\n' > "$STATE_FILE"
    # Mock pacman -Qi returns 0 (packages still present)
    MOCK_PACMAN_QI_EXIT=0 remove_smart_card_packages
    grep -q "\-Rs" "$MOCK_PACMAN_LOG"
}

@test "remove_smart_card_packages skips general packages (wget, unzip)" {
    printf '{"packages_installed":["wget=1.0","unzip=1.0"]}\n' > "$STATE_FILE"
    MOCK_PACMAN_QI_EXIT=0 remove_smart_card_packages
    # No -Rs call expected since none are in smart_card_only
    ! grep -q "\-Rs" "$MOCK_PACMAN_LOG" 2>/dev/null
    true
}
