"""
config.py — Arch Linux / CachyOS constants.

PKCS11_LIB uses the unified Arch path — no multiarch subdirectory.
Valid for both x86_64 and aarch64 on Arch-based distributions.
"""

PKCS11_LIB = "/usr/lib/opensc-pkcs11.so"
PCSCD_UNIT = "pcscd.socket"
OPENSC_CONF = "/etc/opensc/opensc.conf"

# Full package list required for CAC authentication
REQUIRED_PACKAGES = [
    "pcsclite",
    "ccid",
    "opensc",
    "nss",
    "pcsc-tools",
    "unzip",
    "wget",
]

# Subset offered for removal during uninstall
SMART_CARD_PACKAGES = [
    "pcsclite",
    "ccid",
    "opensc",
    "pcsc-tools",
]

# Firefox profile root candidates, relative to $HOME, in preference order.
# CachyOS uses .config/mozilla/firefox; upstream Arch uses .mozilla/firefox.
FIREFOX_PROFILE_ROOTS = [
    ".config/mozilla/firefox",
    ".mozilla/firefox",
]
