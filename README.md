# CAC for Linux Distros

Configure your Linux system for DoW Common Access Card (CAC / smart card)
authentication in Firefox, Chromium, Google Chrome, Microsoft Edge, and Brave.

The tool installs all required packages, imports the DoD CA certificate bundle
into every browser's NSS database, and registers the OpenSC PKCS#11 module —
all in a single command, with full rollback on failure.

---

## Prerequisites

- CachyOS, Arch Linux, EndeavourOS, Manjaro, or another Arch-based distribution
- `sudo` access — run via `sudo python3`, **not** `sudo su` (the tool needs
  `SUDO_USER` to write files as the correct owner)
- All browsers closed before running
- An active internet connection (downloads the DoD certificate bundle during
  setup)
- A CAC reader connected via USB

---

## Installation

```bash
git clone https://github.com/jeremy-g-davenport/cac_for_linux_distros.git
cd cac_for_linux_distros
sudo python3 cac_setup.py
```

The installer will:
1. Install required packages (`pcsclite`, `ccid`, `opensc`, `nss`, `pcsc-tools`)
2. Configure `/etc/opensc/opensc.conf` to force the CAC card driver
3. Enable and start `pcscd.socket`
4. Download and import the DoD CA certificate bundle into all browser NSS databases
5. Register the OpenSC PKCS#11 module with every detected browser profile
6. Run post-install verification

Progress is printed to the terminal. The full log is written to
`/var/log/cac_for_linux_distros_YYYYMMDD_HHMMSS.log`.

---

## Post-Install Verification

After rebooting:

```bash
opensc-tool --list-readers   # Confirm the card reader is detected
```

Then open a browser and navigate to a CAC-protected site (e.g., `https://my.af.mil`).
You should be prompted to select your CAC certificate and enter your PIN.

---

## Uninstallation

```bash
sudo python3 cac_uninstall.py
```

Reverses all changes made by `cac_setup.py` — certificates removed,
PKCS#11 module unregistered, `pcscd` stopped and disabled (if it was not
active before setup), packages optionally removed. The system is returned to
its pre-CAC state, ready for a fresh install test.

All browsers must be closed before running.

---

## Troubleshooting

| Symptom | Resolution |
|---|---|
| Card reader not detected | Reboot, then run `opensc-tool --list-readers`. If still missing, see Issue #P1 in `KNOWN_ISSUES.md`. |
| `pcscd` not running | `sudo systemctl start pcscd.socket` |
| No PIN prompt in browser | Reboot first. If still missing, check `modutil -list -dbdir sql:~/.pki/nssdb` for "CAC Module". |
| PIN prompt in Chrome but not Firefox | Firefox profile may not have been discovered. Run `modutil -list -dbdir sql:~/.config/mozilla/firefox/<profile>/` — see Issue #P5 in `KNOWN_ISSUES.md`. |
| Setup fails with "no readers found" in a VM | USB passthrough may be claimed by another VM — see Issue #P4 in `KNOWN_ISSUES.md`. |
| Certificate dialog does not appear after reboot | Check the install log at `/var/log/cac_for_linux_distros_*.log` for `[ERROR]` entries. |

See `KNOWN_ISSUES.md` for a full list of documented issues and resolutions.

---

## Differences from Upstream linux\_cac

This tool uses the same underlying mechanism as
[`linux_cac`](https://github.com/jdjaxon/linux_cac) but makes several
corrections:

| Issue | linux\_cac behavior | This tool |
|---|---|---|
| `pcscd` not active until reboot | `systemctl enable` only | `enable` + `start` both called |
| Firefox profiles not found on CachyOS | Relies on `pkcs11-register` (hardcodes `~/.mozilla/firefox`) | Uses `modutil` directly against all discovered profile paths |
| NSS files owned by root | `certutil`/`modutil` run as root | All NSS operations run as `$REAL_USER` via `sudo -H -u` |
| CAC card not recognised by OpenSC | No `opensc.conf` change | Forces `card_drivers = cac` in `/etc/opensc/opensc.conf` |
| Partial uninstall risk | No uninstall script | Full uninstall with rollback via `action_log.json` |

See the Assessment section of [`docs/PLAN.md`](docs/PLAN.md) for a detailed
comparison.

---

## Why I'm Building This

I'm an active civilian employee of the DoW. My CAC is my primary credential
for accessing government systems, email, and web portals — the same things
I'd do without friction on a Windows workstation.

Linux support for CAC authentication exists, but it's fragmented: guides go
out of date, distro-specific quirks go undocumented, and setup is a
multi-hour exercise even for experienced users. On CachyOS and other
Arch-based systems, the problem is worse because most guides assume
Debian/Ubuntu.

My goal is a setup tool that is at least as reliable as the Windows
experience — ideally better — with full feature support: browser
authentication, certificate validation, and email signing/encryption.
If it works well for me, it should work well for anyone in a similar
position.

**This tool is not intended to grant access beyond what is already
authorized.** It exists solely to reduce the friction of using a CAC on
Linux to access resources an employee is already cleared and authorized to
use. Nothing here promotes or assists in circumventing agency access
controls, security policies, or acceptable use rules.

---

## Project Plan

### Phase 1 — CLI Backend *(complete)*

A three-layer architecture: Python orchestration (`orchestrator/`), distro
abstraction (`distros/`), and Bash execution units (`lib/*.sh`, `bash/*.sh`).

- [x] Python orchestration layer — subprocess management, state tracking,
      cancellation with automatic rollback, audit log, config snapshots
- [x] Distro abstraction layer — Arch/CachyOS driver; stub for future Debian
- Bash library modules:
  - [x] `lib/log.sh` — color-coded terminal output + persistent log file
  - [x] `lib/detect.sh` — root/user/env validation, tool checks, module unload
  - [x] `lib/aur.sh` — AUR helper detection (`paru`/`yay`), non-root install wrapper
  - [x] `lib/packages.sh` — pacman sync + package installation
  - [x] `lib/opensc_conf.sh` — force CAC driver in `/etc/opensc/opensc.conf`
  - [x] `lib/service.sh` — enable + start `pcscd.socket`
  - [x] `lib/certs.sh` — DoD certificate bundle download + checksum validation
  - [x] `lib/browser.sh` — browser detection, NSS database discovery
  - [x] `lib/import.sh` — `certutil` certificate import into all NSS databases
  - [x] `lib/pkcs11.sh` — `modutil` PKCS11 module registration
  - [x] `lib/verify.sh` — post-install verification
- [x] Install and uninstall entry points — `cac_setup.py`, `cac_uninstall.py`,
      `bash/install.sh`, `bash/uninstall.sh`
- [x] Testing suite — BATS unit tests with mocked system commands; Python
      `unittest` for the orchestration layer
- [x] User documentation — `README.md`, `KNOWN_ISSUES.md`

### Phase 2 — PyQt6 GUI Application *(planned — placeholder)*

- [ ] Installation wizard (`QWizard`) driven by the Phase 1 orchestration layer
- [ ] Application loading splash screen
- [ ] System tray indicator (`libayatana-appindicator`) with card status and
      context menu
- [ ] Main window — ActivClient-style smart card viewer (certificates, reader
      status, card identity, PIN management)

### Phase 3 — GitHub Actions CI/CD *(planned)*

- [ ] `ci.yml` — ShellCheck, `bash -n`, Python lint (`ruff`), BATS unit tests
      (mocked on `ubuntu-latest`; real Arch packages via `archlinux:latest`
      container), Python `unittest` matrix (3.10 / 3.11 / 3.12)
- [ ] `release.yml` — tag-triggered GitHub Release with source archive and
      SHA-256 checksum

### Phase 4 — Quarterly Release Cadence *(planned)*

Conditional quarterly releases (cut only when corrections have accumulated),
structured issue triage, per-item implementation plans for all accepted
changes, and contributor communication standards. See `docs/PLAN.md`
Section 10 for the full process definition.

### Phase 5 — Help Guide *(planned)*

In-application Help dialog (`F1` / Help menu) with a navigable topic tree,
real-time search with match highlighting, and full content covering
installation, troubleshooting, certificate management, snapshots, and more.

---

## Supported Distributions

| Distribution family | Examples | Status |
|---|---|---|
| Arch-based | CachyOS, Arch Linux, EndeavourOS, Manjaro | **Supported** |

### Planned Distribution Support

| Distribution family | Examples | Notes |
|---|---|---|
| Red Hat-based | Fedora, RHEL, Rocky Linux, AlmaLinux | `dnf`/`rpm` package backend required |
| Debian-based | Debian, Ubuntu, Linux Mint, Pop!\_OS | `apt`/`dpkg` package backend required; see also the upstream [linux_cac](linux_cac/) reference |

> Contributions for additional package backends are welcome once the Arch
> implementation is stable. The distro abstraction layer (`distros/`) is
> designed to make adding a new distro a self-contained change.

## Supported Architectures

| Architecture | Status | Notes |
|---|---|---|
| `x86_64` | **Supported** | Primary target |
| `aarch64` | **Supported** | ARM64: Raspberry Pi 4/5, Asahi Linux, ARM thin clients |
| `riscv64` | Future consideration | Negligible deployment footprint today |

---

## Contributing

See `CONTRIBUTING.md` for the full contribution guide,
including branch naming conventions, the pre-merge checklist, and required
CI checks.

**Branch naming:** `p<phase>/<name>` for phase work (e.g. `p1/packages`,
`p2/main-window`); `ci/<name>` for repository infrastructure. The full
branch name table is in [`docs/PLAN.md`](docs/PLAN.md).

---

## License

MIT — see [LICENSE](LICENSE) for full text.
Copyright (c) 2026 Jeremy G. Davenport
