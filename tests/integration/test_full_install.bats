#!/usr/bin/env bats
# tests/integration/test_full_install.bats — Full install/uninstall integration tests.
#
# These tests require a real CachyOS/Arch system with:
#   - The full package set (pcsclite, ccid, opensc, nss)
#   - Firefox or Chromium installed
#   - sudo access
#
# Skipped automatically in hosted CI unless CI_INTEGRATION=1 is set.
# A self-hosted Arch runner sets CI_INTEGRATION=1 to enable them.

setup() {
    if [[ -z "${CI_INTEGRATION:-}" ]]; then
        skip "integration tests require CI_INTEGRATION=1 (real Arch system)"
    fi
    if [[ $(id -u) -ne 0 ]]; then
        skip "integration tests require root (sudo)"
    fi
    source "$(dirname "$BATS_TEST_FILENAME")/../../tests/helpers/set_test_env.sh"
}

@test "full install completes without errors" {
    run python3 cac_setup.py
    [ "$status" -eq 0 ]
}

@test "verify_pcscd_service returns active after install" {
    source lib/log.sh
    source lib/service.sh
    log_init
    run verify_pcscd_service
    [ "$status" -eq 0 ]
}

@test "full uninstall completes without errors" {
    run python3 cac_uninstall.py
    [ "$status" -eq 0 ]
}
