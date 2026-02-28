"""
config.py — Red Hat family (Fedora, RHEL, CentOS Stream, Rocky, AlmaLinux) constants.

PKCS11_LIB uses lib64 — Red Hat multiarch convention on x86_64 and aarch64.
opensc.conf lives at the flat path /etc/opensc.conf on Fedora/RHEL; the opensc
RPM does not use an /etc/opensc/ subdirectory as Arch does.
"""

PKCS11_LIB = "/usr/lib64/opensc-pkcs11.so"
PCSCD_UNIT = "pcscd.socket"

# /etc/opensc.conf — flat path used by Fedora/RHEL opensc RPM.
# Arch uses /etc/opensc/opensc.conf (subdirectory).
OPENSC_CONF = "/etc/opensc.conf"

# Full package list required for CAC authentication on Fedora/RHEL.
# Key differences from Arch:
#   pcsclite    → pcsc-lite        (RPM naming uses a hyphen)
#   nss         → nss-tools        (certutil/modutil are in the -tools subpackage)
#   pcsc-tools  → pcsc-lite-utils  (pcsc_scan lives here on Fedora)
# Verify pcsc-lite-utils name on target: dnf provides pcsc_scan
REQUIRED_PACKAGES = [
    "pcsc-lite",
    "ccid",
    "opensc",
    "nss-tools",
    "pcsc-lite-utils",
    "unzip",
    "wget",
]

# Subset offered for removal during uninstall (excludes unzip/wget/nss-tools)
SMART_CARD_PACKAGES = [
    "pcsc-lite",
    "ccid",
    "opensc",
    "pcsc-lite-utils",
]

# Firefox profile root candidates, relative to $HOME.
# Fedora uses the standard upstream path — no CachyOS variant.
FIREFOX_PROFILE_ROOTS = [
    ".mozilla/firefox",
]
