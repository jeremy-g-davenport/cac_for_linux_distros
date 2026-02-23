#!/bin/bash
# lib/opensc_conf.sh — OpenSC CAC driver configuration
#
# Provides: configure_opensc_cac_driver
#
# Without explicit CAC driver forcing, OpenSC's auto-detection heuristic
# may select the PIV-II driver instead of the CAC driver, silently breaking
# card recognition even when the reader is detected. This is a known failure
# mode documented in KNOWN_ISSUES.md #P3.
#
# Source: M-Pepper linux-cac-walkthrough
# No set -euo pipefail — inherited from bash/install.sh or bash/uninstall.sh.

[[ -v OPENSC_CONF ]] || OPENSC_CONF="/etc/opensc/opensc.conf"

configure_opensc_cac_driver() {
    log_section "OpenSC Configuration"

    if [[ ! -f "$OPENSC_CONF" ]]; then
        log_warn "$OPENSC_CONF not found — skipping (opensc may not be installed yet)"
        return 0
    fi

    # Idempotent: if force_card_driver is already present, nothing to do.
    if grep -q "force_card_driver" "$OPENSC_CONF" 2>/dev/null; then
        log_info "OpenSC CAC driver forcing already configured."
        return 0
    fi

    log_info "Adding CAC driver forcing to $OPENSC_CONF..."

    if grep -q "app default {" "$OPENSC_CONF"; then
        # Insert immediately after the `app default {` line
        sed -i '/app default {/a\\tcard_drivers = cac;\n\tforce_card_driver = cac;' "$OPENSC_CONF"
    else
        # No `app default` block — append one at the end
        printf '\napp default {\n\tcard_drivers = cac;\n\tforce_card_driver = cac;\n}\n' \
            >> "$OPENSC_CONF"
    fi

    log_success "OpenSC CAC driver forcing configured."
}
