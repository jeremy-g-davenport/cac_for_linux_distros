# CAC for CachyOS

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

### Phase 1 — CLI Backend (Bash + Python orchestration)

- [ ] **Architecture & project structure** — define module boundaries, entry
      points, and environment-variable contract between Python orchestrator and
      Bash execution units
- [ ] **Core library implementation** — `lib/log.sh`, `lib/detect.sh`,
      `lib/aur.sh`, `lib/packages.sh`, `lib/service.sh`, `lib/certs.sh`,
      `lib/browser.sh`, `lib/import.sh`, `lib/pkcs11.sh`, `lib/verify.sh`
- [ ] **OpenSC configuration** — write `opensc.conf` CAC driver forcing
      (`force_card_driver = cac`); detect and unload conflicting kernel modules
      (`pn533`, `nfc`) before reader access
- [ ] **Legacy PKCS11 cleanup** — remove stale `cackey`/`coolkey` NSS entries
      before registering OpenSC to prevent silent auth failures
- [ ] **Certificate import ordering** — sort root CAs before intermediates to
      ensure correct chain validation
- [ ] **Enhanced verification** — `pkcs11-tool --list-objects` to confirm card
      objects are readable through OpenSC after setup
- [ ] **VMware/Omnissa Horizon symlink** *(optional)* — link `opensc-pkcs11.so`
      into Horizon's pkcs11 directory for virtual desktop environments
- [ ] **Install workflow** — `cac_setup.py` orchestrator + `bash/install.sh`
      execution unit
- [ ] **Uninstall workflow** — `cac_uninstall.py` orchestrator +
      `bash/uninstall.sh` execution unit
- [ ] **Testing suite** — BATS unit tests for all library modules; manual
      integration test checklist
- [ ] **CI pipeline** — GitHub Actions: ShellCheck, `bash -n`, and BATS on
      every push

### Phase 2 — PyQt6 GUI Application *(placeholder — not started)*

- [ ] GUI design and UX requirements
- [ ] System tray integration (`libayatana-appindicator`)
- [ ] GUI implementation and packaging
- [ ] PAM login integration (`pam_pkcs11`) — use CAC for Linux system login
      with DoD DN subject mapping

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
> implementation is stable.

## Supported Architectures

| Architecture | Status | Notes |
|---|---|---|
| `x86_64` | **In Development** | Primary target |
| `aarch64` | Future consideration | ARM64: Raspberry Pi 4/5, Asahi Linux (Apple Silicon), ARM thin clients |
| `riscv64` | Future consideration | Negligible deployment footprint today |

## License

MIT — see [LICENSE](LICENSE) for full text.
Copyright (c) 2026 Jeremy G. Davenport