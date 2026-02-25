#!/bin/bash
# lib/service.sh — pcscd smart card daemon management
#
# Provides: record_pcscd_state, enable_pcscd, verify_pcscd_service, disable_pcscd
#
# On Arch/CachyOS, pcscd uses socket activation. pcscd.socket must be both
# enabled (survives reboot) and started (active in the current session).
# Managing pcscd.service alone is incorrect — socket activation requires
# pcscd.socket. Addresses KNOWN_ISSUES.md #P8.
#
# No set -euo pipefail — inherited from bash/install.sh or bash/uninstall.sh.

record_pcscd_state() {
    # Capture whether pcscd.socket was active before we touched it so the
    # uninstall flow can decide whether to disable it.
    local was_active="false"
    if systemctl is-active --quiet pcscd.socket 2>/dev/null; then
        was_active="true"
    fi
    echo "STATE:pcscd_was_active_before=${was_active}"
    log_info "pcscd.socket active before setup: $was_active"
}

enable_pcscd() {
    log_section "Smart Card Daemon"

    # Both enable AND start are required:
    # - enable: registers the unit for next boot
    # - start:  activates it in the current session without a reboot
    if ! log_cmd systemctl enable "${PCSCD_UNIT}"; then
        log_error "Failed to enable ${PCSCD_UNIT}"
        exit 1
    fi
    if ! log_cmd systemctl start "${PCSCD_UNIT}"; then
        log_error "Failed to start ${PCSCD_UNIT}"
        exit 1
    fi

    # pacman's post-transaction hook runs `udevadm control --reload` after
    # installing pcsclite/ccid but does NOT run `udevadm trigger`. Without a
    # trigger, a USB card reader that was already connected before ccid was
    # installed keeps its pre-ccid device-node permissions. When pcscd.service
    # later starts (via socket activation), libusb_open() returns
    # LIBUSB_ERROR_ACCESS and the reader is never found.
    # Running the trigger + settle here ensures ccid udev rules are applied to
    # the existing device before pcscd.service starts. See KNOWN_ISSUES.md #5e.
    log_info "Applying udev rules to USB devices (required for card reader access)..."
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger --subsystem-match=usb 2>/dev/null || true
    udevadm settle --timeout=5 2>/dev/null || true

    # Explicitly start pcscd.service so it scans for card readers now, during
    # install, after the udev trigger above has set correct device permissions.
    # Without this, socket activation may start pcscd.service at some later
    # arbitrary point, possibly before a manual udev trigger is run.
    log_info "Starting pcscd.service to scan for connected card readers..."
    if ! log_cmd systemctl start pcscd.service; then
        log_warn "pcscd.service did not start — it will start on first PKCS11 connection"
    fi

    log_success "${PCSCD_UNIT} enabled and started."
    echo "ACTION:service_enable|${PCSCD_UNIT}|was_enabled_before=false"
    echo "ACTION:service_start|${PCSCD_UNIT}|was_active_before=false"
}

verify_pcscd_service() {
    # Returns 0 if pcscd.socket is active, non-zero otherwise.
    # Callers should check the return code; this function does not exit on failure.
    systemctl is-active --quiet "${PCSCD_UNIT}"
}

disable_pcscd() {
    # Used by uninstall script. Stops and disables pcscd.socket and pcscd.service.
    # Errors are non-fatal (units may already be stopped/disabled).
    log_info "Stopping and disabling pcscd..."
    systemctl stop pcscd.socket pcscd.service 2>/dev/null || true
    systemctl disable pcscd.socket 2>/dev/null || true
    log_success "pcscd disabled."
}
