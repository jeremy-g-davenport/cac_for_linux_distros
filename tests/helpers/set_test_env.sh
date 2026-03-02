#!/bin/bash
# tests/helpers/set_test_env.sh — Export required env vars, distro-aware.
#
# Usage: source tests/helpers/set_test_env.sh
#
# Required when running bash/install.sh or bash/uninstall.sh directly
# (without the Python orchestrator) for integration testing or the
# developer standalone escape hatch.  Python normally injects these
# via orchestrator/setup_flow.py::_build_env().

_id="$(. /etc/os-release 2>/dev/null && echo "${ID:-arch}")"
_id_like="$(. /etc/os-release 2>/dev/null && echo "${ID_LIKE:-}")"

case "$_id" in
    fedora|rhel|centos|rocky|almalinux)
        _FAMILY="redhat" ;;
    *)
        case "$_id_like" in
            *fedora*|*rhel*) _FAMILY="redhat" ;;
            *)               _FAMILY="arch"   ;;
        esac ;;
esac

if [[ "$_FAMILY" == "redhat" ]]; then
    export PKCS11_LIB="/usr/lib64/opensc-pkcs11.so"
else
    export PKCS11_LIB="/usr/lib/opensc-pkcs11.so"
fi

export PCSCD_UNIT="pcscd.socket"
export REAL_USER="${SUDO_USER:-$USER}"
export REAL_HOME="${HOME}"
export STATE_FILE="/var/lib/cac_for_linux_distros/state.json"

unset _id _id_like _FAMILY
