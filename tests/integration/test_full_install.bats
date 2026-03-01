#!/usr/bin/env bats
# tests/integration/test_full_install.bats — Distro-agnostic full install/uninstall tests.
#
# Supported distro families:
#   arch    — Arch, CachyOS, EndeavourOS, Manjaro
#   redhat  — Fedora, RHEL, CentOS Stream, Rocky, AlmaLinux
#
# Requirements:
#   - Run as root (sudo)
#   - .venv/ present at repo root with requirements installed
#   - CI_INTEGRATION=1 set in environment
#
# Run:
#   sudo CI_INTEGRATION=1 bats tests/integration/test_full_install.bats
#
# The install and uninstall tests run WITHOUT the 'run' wrapper so that
# dnf/pacman progress streams live to the terminal instead of being swallowed.

# ---------------------------------------------------------------------------
# Distro detection helper
# ---------------------------------------------------------------------------

_detect_distro_family() {
    local id id_like
    id="$(. /etc/os-release 2>/dev/null && echo "${ID:-}")"
    id_like="$(. /etc/os-release 2>/dev/null && echo "${ID_LIKE:-}")"
    case "$id" in
        arch|cachyos|endeavouros|manjaro)    echo "arch"   ; return ;;
        fedora|rhel|centos|rocky|almalinux) echo "redhat" ; return ;;
        ubuntu|debian|linuxmint|pop)        echo "debian" ; return ;;
    esac
    case "$id_like" in
        *arch*)            echo "arch"   ; return ;;
        *fedora*|*rhel*)   echo "redhat" ; return ;;
        *debian*|*ubuntu*) echo "debian" ; return ;;
    esac
    echo "unknown"
}

# ---------------------------------------------------------------------------
# setup — runs before every test; sets distro-specific variables
# ---------------------------------------------------------------------------

setup() {
    if [[ -z "${CI_INTEGRATION:-}" ]]; then
        skip "integration tests require CI_INTEGRATION=1"
    fi
    if [[ $(id -u) -ne 0 ]]; then
        skip "integration tests require root"
    fi

    DISTRO_FAMILY="$(_detect_distro_family)"

    case "$DISTRO_FAMILY" in
        arch)
            INTEG_PKG_QUERY="pacman -Qi"
            INTEG_SMART_CARD_PKGS="pcsclite ccid opensc"
            INTEG_PKCS11_LIB="/usr/lib/opensc-pkcs11.so"
            INTEG_OPENSC_CONF="/etc/opensc/opensc.conf"
            ;;
        redhat)
            INTEG_PKG_QUERY="rpm -q"
            INTEG_SMART_CARD_PKGS="pcsc-lite ccid opensc"
            INTEG_PKCS11_LIB="/usr/lib64/opensc-pkcs11.so"
            INTEG_OPENSC_CONF="/etc/opensc.conf"
            ;;
        *)
            local detected_id
            detected_id="$(. /etc/os-release 2>/dev/null && echo "${ID:-unknown}")"
            skip "unsupported distro family: $DISTRO_FAMILY (ID=$detected_id)"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

@test "full install completes without errors" {
    # No 'run' wrapper — output streams live so dnf/pacman progress is visible.
    .venv/bin/python cac_setup.py
}

# ---------------------------------------------------------------------------
# Post-install verification
# ---------------------------------------------------------------------------

@test "smart card packages are installed after install" {
    local -a query pkgs
    read -ra query <<< "$INTEG_PKG_QUERY"
    read -ra pkgs  <<< "$INTEG_SMART_CARD_PKGS"
    for pkg in "${pkgs[@]}"; do
        run "${query[@]}" "$pkg"
        [ "$status" -eq 0 ]
    done
}

@test "opensc.conf has force_card_driver = cac" {
    grep -q "^force_card_driver[[:space:]]*=[[:space:]]*cac" "$INTEG_OPENSC_CONF"
}

@test "pkcs11 library exists at distro-expected path" {
    [ -f "$INTEG_PKCS11_LIB" ]
}

@test "pcscd socket is active after install" {
    run systemctl is-active pcscd.socket
    [ "$status" -eq 0 ]
}

@test "state file written after install" {
    [ -f "/var/lib/cac_for_linux_distros/state.json" ]
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------

@test "full uninstall completes without errors" {
    # No 'run' wrapper — output streams live.
    .venv/bin/python cac_uninstall.py
}

@test "pcscd socket is not active after uninstall" {
    run systemctl is-active pcscd.socket
    [ "$status" -ne 0 ]
}

@test "state file absent or packages cleared after uninstall" {
    # Either the state file is gone, or packages_installed is empty.
    if [[ -f "/var/lib/cac_for_linux_distros/state.json" ]]; then
        run .venv/bin/python -c "
import json, sys
state = json.load(open('/var/lib/cac_for_linux_distros/state.json'))
sys.exit(0 if not state.get('packages_installed') else 1)
"
        [ "$status" -eq 0 ]
    fi
}
