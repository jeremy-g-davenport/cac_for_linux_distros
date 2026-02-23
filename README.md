# CAC for Linux Distros

A DoW Common Access Card (CAC / smart card) setup tool for CachyOS and other
Arch-based Linux distributions.

The goal is a reliable, well-tested installer that configures the full CAC
stack — drivers, certificates, PKCS#11 module, and browser NSS databases —
with minimal manual steps and clear diagnostics when something goes wrong.

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

### Phase 1 — CLI Backend *(in development)*

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
  - [ ] `lib/import.sh` — `certutil` certificate import into all NSS databases
  - [ ] `lib/pkcs11.sh` — `modutil` PKCS11 module registration
  - [ ] `lib/verify.sh` — post-install verification
- [ ] Install and uninstall entry points — `cac_setup.py`, `cac_uninstall.py`,
      `bash/install.sh`, `bash/uninstall.sh`
- [ ] Testing suite — BATS unit tests with mocked system commands; Python
      `unittest` for the orchestration layer
- [ ] User documentation — `README.md`, `KNOWN_ISSUES.md`

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
| Arch-based | CachyOS, Arch Linux, EndeavourOS, Manjaro | **In Development** |

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
| `x86_64` | **In Development** | Primary target |
| `aarch64` | **In Development** | ARM64: Raspberry Pi 4/5, Asahi Linux, ARM thin clients |
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

