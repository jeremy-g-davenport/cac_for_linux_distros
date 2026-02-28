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

# ── Arch / pacman path (default fallback) ─────────────────────────────────────

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
    # PKG_REMOVE_PREFIX defaults to "pacman -Rns --noconfirm"
    grep -q "pacman -Rns" "$MOCK_PACMAN_LOG"
}

@test "remove_smart_card_packages skips general packages (wget, unzip)" {
    printf '{"packages_installed":["wget=1.0","unzip=1.0"]}\n' > "$STATE_FILE"
    MOCK_PACMAN_QI_EXIT=0 remove_smart_card_packages
    # No pacman -Rns call expected since none are in SMART_CARD_PACKAGES_LIST
    ! grep -q "pacman -Rns" "$MOCK_PACMAN_LOG" 2>/dev/null
    true
}

# ── Red Hat / dnf path (via env var injection) ────────────────────────────────

_setup_redhat_env() {
    # Simulate the env vars Python injects for Red Hat systems.
    # Unset Arch-specific arrays so packages.sh re-reads from env vars.
    unset REQUIRED_PACKAGES SMART_CARD_PACKAGES_LIST
    export PKG_QUERY_CMD="rpm -q"
    export PKG_SYNC_CMD="dnf upgrade -y"
    export PKG_INSTALL_PREFIX="dnf install -y"
    export PKG_REMOVE_PREFIX="dnf remove -y"
    export REQUIRED_PACKAGES_ENV="pcsc-lite ccid opensc nss-tools"
    export SMART_CARD_PACKAGES_ENV="pcsc-lite ccid opensc pcsc-tools"
    # Re-source packages.sh so it picks up the new env vars
    _source_lib "packages"
}

@test "is_package_installed uses rpm -q when PKG_QUERY_CMD is set" {
    _setup_redhat_env
    MOCK_RPM_Q_EXIT=0 run is_package_installed "opensc"
    [ "$status" -eq 0 ]
    grep -q "rpm -q opensc" "$MOCK_RPM_LOG"
}

@test "is_package_installed returns non-zero via rpm -q when package missing" {
    _setup_redhat_env
    MOCK_RPM_Q_EXIT=1 run is_package_installed "missing-pkg"
    [ "$status" -ne 0 ]
}

@test "install_official_packages invokes dnf upgrade when PKG_SYNC_CMD is set" {
    _setup_redhat_env
    MOCK_RPM_Q_EXIT=0 install_official_packages
    grep -q "dnf upgrade" "$MOCK_DNF_LOG"
}

@test "install_official_packages invokes dnf install for missing packages" {
    _setup_redhat_env
    MOCK_RPM_Q_EXIT=1 install_official_packages
    grep -q "dnf install" "$MOCK_DNF_LOG"
}

@test "install_official_packages uses REQUIRED_PACKAGES_ENV package list" {
    _setup_redhat_env
    MOCK_RPM_Q_EXIT=1 install_official_packages
    # pcsc-lite is from the Red Hat list (not pcsclite which is Arch)
    grep -q "pcsc-lite" "$MOCK_DNF_LOG"
}

@test "remove_smart_card_packages invokes dnf remove when PKG_REMOVE_PREFIX is set" {
    _setup_redhat_env
    printf '{"packages_installed":["pcsc-lite=1.0","opensc=1.0"]}\n' > "$STATE_FILE"
    MOCK_RPM_Q_EXIT=0 remove_smart_card_packages
    grep -q "dnf remove" "$MOCK_DNF_LOG"
}
