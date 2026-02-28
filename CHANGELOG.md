# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
Versioning: [Semantic Versioning](https://semver.org/)

## [Unreleased]

## [0.1.0] - 2026-02-26

### Added
- Python orchestration layer (`orchestrator/`) — subprocess management, state
  tracking, cancellation with automatic rollback, audit log, config snapshots
- Distro abstraction layer (`distros/`) — Arch/CachyOS driver implementing
  `DistroDriver` ABC; stub interface for future Debian/Fedora support
- `lib/log.sh` — color-coded terminal output and persistent log file
- `lib/detect.sh` — root/user/environment validation, tool checks, module unload
- `lib/aur.sh` — AUR helper detection (`paru`/`yay`), non-root install wrapper
- `lib/packages.sh` — pacman full sync and package installation
- `lib/opensc_conf.sh` — force CAC card driver in `/etc/opensc/opensc.conf`
- `lib/service.sh` — enable and start `pcscd.socket`; detect CCID readers via
  sysfs and write per-device udev rules to fix `LIBUSB_ERROR_ACCESS`
- `lib/certs.sh` — DoD CA certificate bundle download with SHA-256 checksum
  verification
- `lib/browser.sh` — browser detection and NSS database discovery (Firefox,
  Chromium, Chrome, Edge, Brave)
- `lib/import.sh` — `certutil` certificate import into all discovered NSS
  databases, run as `$REAL_USER` to prevent root-owned NSS file corruption
- `lib/pkcs11.sh` — `modutil` PKCS#11 module registration across all profiles
- `lib/verify.sh` — post-install verification (pcscd active, certs present,
  module registered)
- `cac_setup.py` and `bash/install.sh` — install entry points
- `cac_uninstall.py` and `bash/uninstall.sh` — full uninstall with rollback via
  `action_log.json`
- BATS unit test suite (`tests/*.bats`) with mocked system commands
- Python unit tests (`tests/test_orchestrator/`) for orchestration layer
- GitHub Actions CI (`ci.yml`) — ShellCheck, `bash -n`, `ruff`, BATS (mocked on
  ubuntu-latest; real Arch packages via archlinux:latest), Python unittest
  matrix (3.10 / 3.11 / 3.12)
- GitHub Actions release workflow (`release.yml`) — tag-triggered release with
  source archive and SHA-256 checksum

### Fixed
- `pcscd` not active until reboot: `enable` + `start` both called on
  `pcscd.socket` (not `pcscd.service`)
- Firefox profiles not found on CachyOS: uses `modutil` directly against
  `~/.config/mozilla/firefox/` profiles (bypasses `pkcs11-register` which
  hardcodes `~/.mozilla/firefox/`)
- NSS files owned by root: all `certutil`/`modutil` calls run as `$REAL_USER`
  via `sudo -H -u`
- CAC card not recognised by OpenSC: creates `/etc/opensc/opensc.conf` when
  absent and forces `card_drivers = cac`
- `LIBUSB_ERROR_ACCESS` on CCID readers in VMs: detects readers via sysfs and
  writes per-device udev rules followed by `udevadm trigger`

[Unreleased]: https://github.com/jeremy-g-davenport/cac_for_linux_distros/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/jeremy-g-davenport/cac_for_linux_distros/releases/tag/v0.1.0
