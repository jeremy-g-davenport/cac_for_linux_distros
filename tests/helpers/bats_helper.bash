#!/usr/bin/env bash
# tests/helpers/bats_helper.bash — Common BATS test helpers.
# Load with:  load 'helpers/bats_helper'  (relative to test file)

# Set up all environment variables required by lib/*.sh functions.
_setup_test_env() {
    export PKCS11_LIB="/usr/lib/opensc-pkcs11.so"
    export PCSCD_UNIT="pcscd.socket"
    export REAL_USER="testuser"
    export REAL_HOME="$BATS_TMPDIR/home/testuser"
    export STATE_FILE="$BATS_TMPDIR/state.json"
    export NSS_DATABASES=()
    export _CAC_LOG_FILE
    _CAC_LOG_FILE="$(mktemp)"
    # Override lib/service.sh module-level default so tests write to BATS_TMPDIR
    # instead of /etc/udev/rules.d/ (which requires root and is not writable in CI).
    # Must be set before _source_lib "service" so the :=  default is not applied.
    export _CCID_RULES_FILE="$BATS_TMPDIR/99-cac-ccid.rules"
    mkdir -p "$REAL_HOME"
}

# Prepend the mocks directory to PATH so mock stubs shadow real system binaries.
_use_mocks() {
    local mocks_dir
    mocks_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../mocks" && pwd)"
    export PATH="$mocks_dir:$PATH"
}

# Initialise per-test mock log files in $BATS_TMPDIR.
_setup_mock_logs() {
    export MOCK_PACMAN_LOG="$BATS_TMPDIR/mock_pacman.log"
    export MOCK_SYSTEMCTL_LOG="$BATS_TMPDIR/mock_systemctl.log"
    export MOCK_MODUTIL_LOG="$BATS_TMPDIR/mock_modutil.log"
    export MOCK_CERTUTIL_LOG="$BATS_TMPDIR/mock_certutil.log"
    export MOCK_WGET_LOG="$BATS_TMPDIR/mock_wget.log"
    export MOCK_UNZIP_LOG="$BATS_TMPDIR/mock_unzip.log"
    export MOCK_UDEVADM_LOG="$BATS_TMPDIR/mock_udevadm.log"
    export MOCK_DNF_LOG="$BATS_TMPDIR/mock_dnf.log"
    export MOCK_RPM_LOG="$BATS_TMPDIR/mock_rpm.log"
    rm -f "$MOCK_PACMAN_LOG" "$MOCK_SYSTEMCTL_LOG" "$MOCK_MODUTIL_LOG" \
          "$MOCK_CERTUTIL_LOG" "$MOCK_WGET_LOG" "$MOCK_UNZIP_LOG" \
          "$MOCK_UDEVADM_LOG" "$MOCK_DNF_LOG" "$MOCK_RPM_LOG" \
          "$_CCID_RULES_FILE"
}

# Source the SCRIPT_DIR-resolved lib file.
_source_lib() {
    local lib_name="$1"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    # shellcheck source=/dev/null
    source "$script_dir/lib/$lib_name.sh"
}
