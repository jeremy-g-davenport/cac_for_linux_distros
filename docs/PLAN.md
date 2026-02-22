# CachyOS CAC Setup — Implementation Plan

**Target Platform:** CachyOS (Arch-based Linux, x86_64 and aarch64)
**Primary Language:** Python 3.10+ (orchestrator, entry points, distro abstraction)
**System Operations:** Bash (`lib/*.sh`, `bash/*.sh` — invoked by Python via subprocess)
**Source Reference:** `linux_cac/cac_setup.sh` (Bash, Debian/Ubuntu)
**Work Directory:** `cachy_cac/` (sibling of `linux_cac/`)
**Purpose:** Configure CachyOS for DoW Common Access Card (CAC/smart card) authentication in web browsers via OpenSC, pcscd, NSS cert databases, and PKCS11 module registration. Phase 2 (planned) will provide a PyQt6 GUI application with installer, system tray indicator, and ActivClient-style smart card viewer. Phase 3 (planned) establishes GitHub Actions CI/CD. Phase 4 (planned) defines quarterly release cadence and GitHub Issue/PR management.

## Quick Start

```bash
cd cachy_cac
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

---

## Branch Names

Short branch names for feature development, organized by phase. Prefix scheme: `p<phase>/` for phase-scoped work; `ci/` for repository infrastructure (Section 12).

### Phase 1 — CLI Backend

| Branch | Covers |
|---|---|
| `p1/orchestrator` | Steps 0 + 0.5 — `orchestrator/` package and `distros/` abstraction layer |
| `p1/log` | Step 1 — `lib/log.sh` |
| `p1/detect` | Step 2 — `lib/detect.sh` |
| `p1/aur` | Step 3 — `lib/aur.sh` |
| `p1/packages` | Step 4 — `lib/packages.sh` |
| `p1/opensc-conf` | Step 4.5 — `lib/opensc_conf.sh` |
| `p1/service` | Step 5 — `lib/service.sh` |
| `p1/certs` | Step 6 — `lib/certs.sh` |
| `p1/browser` | Step 7 — `lib/browser.sh` |
| `p1/import` | Step 8 — `lib/import.sh` |
| `p1/pkcs11` | Step 9 — `lib/pkcs11.sh` |
| `p1/verify` | Step 10 — `lib/verify.sh` |
| `p1/entry-points` | Step 11 — `cac_setup.py`, `bash/install.sh`, `bash/uninstall.sh` |
| `p1/uninstall` | Section 4 — `cac_uninstall.py` (depends on `p1/entry-points`) |
| `p1/tests` | Section 5 — `tests/*.bats`, `tests/mocks/`, `tests/test_orchestrator/` |
| `p1/readme` | Step 12 — `README.md`, `KNOWN_ISSUES.md` |

### Phase 2 — PyQt6 GUI

| Branch | Covers |
|---|---|
| `p2/install-wizard` | Section 8.1 — `QWizard` installation dialog |
| `p2/splash` | Section 8.2 — `QSplashScreen` loading screen |
| `p2/indicator` | Section 8.3 — App indicator and tray context menu |
| `p2/main-window` | Section 8.4 — Main ActivClient-style viewer |

### Phase 3 — GitHub Actions CI/CD

| Branch | Covers |
|---|---|
| `p3/ci` | Section 9.3 + 12.1 — `.github/workflows/ci.yml` (all jobs including `bats-arch`) |
| `p3/release` | Section 9.4 — `.github/workflows/release.yml` |

### Phase 4 — Release Cadence / Issue Management

Phase 4 is process, not code. Associated repository files are in `ci/` branches below.

### Phase 5 — Help Guide

| Branch | Covers |
|---|---|
| `p5/help-engine` | Sections 11.1–11.4 — `HelpDialog`, `HelpSearchIndex`, `renderer.py` |
| `p5/help-content` | Section 11.5 — `gui/help/content/*.md`, `index.json` (can run parallel to engine) |

### CI/CD Infrastructure (Section 12)

| Branch | Covers |
|---|---|
| `ci/repo-init` | Sections 12.7–12.9 — `SECURITY.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `version.py` |
| `ci/templates` | Section 12.3 — `.github/ISSUE_TEMPLATE/`, `.github/pull_request_template.md` |
| `ci/codeowners` | Section 12.4 — `.github/CODEOWNERS` |
| `ci/automations` | Sections 12.5–12.6 — `dependabot.yml`, `stale.yml` |
| `ci/precommit` | Section 12.11 — `.pre-commit-config.yaml` |

---

## Getting Started

Before implementing any step, create the `cachy_cac/` directory as a sibling of `linux_cac/` in the project root:

```bash
mkdir -p "/Cloud/Dropbox/VS Code Projects/CAC for CachyOS/cachy_cac"
```

**Do not copy files from `linux_cac/`.** All implementation is written from scratch. The `linux_cac/cac_setup.sh` source is used only as a reference.

Once the directory exists, copy this plan document into it as `cachy_cac/PLAN.md`. From that point, all work happens inside `cachy_cac/`.

---

## Table of Contents

- [Branch Names](#branch-names)
0. [Architecture Overview](#0-architecture-overview)
   - [0.1 Three-Layer Model](#01-three-layer-model)
   - [0.2 Python–Bash Communication Contract](#02-pythonbash-communication-contract)
   - [0.3 Distro Abstraction — Adding a New Distro](#03-distro-abstraction--adding-a-new-distro)
   - [0.4 Install/Uninstall Symmetry Contract](#04-installuninstall-symmetry-contract)
   - [0.5 Threading, Cancellation, and Non-Blocking Design](#05-threading-cancellation-and-non-blocking-design)
   - [0.6 Action Log and Comprehensive Audit Trail](#06-action-log-and-comprehensive-audit-trail)
   - [0.7 Configuration Snapshots and Config-Only Restore](#07-configuration-snapshots-and-config-only-restore)
1. [Source Repository Assessment](#1-source-repository-assessment)
2. [Project Structure](#2-project-structure)
3. [Implementation Steps](#3-implementation-steps)
   - [Step 0: Python Orchestration Layer](#step-0-python-orchestration-layer--orchestrator)
   - [Step 0.5: Distro Abstraction Layer](#step-05-distro-abstraction-layer--distros)
   - [Step 1: Logging Infrastructure](#step-1-logging-infrastructure--liblogsh)
   - [Step 2: Architecture & Environment Detection](#step-2-architecture--environment-detection--libdetectsh)
   - [Step 3: AUR Helper Detection](#step-3-aur-helper-detection--libaursh)
   - [Step 4: Package Installation](#step-4-package-installation--libpackagessh)
   - [Step 4.5: OpenSC Configuration](#step-45-opensc-configuration--libopensc_confsh)
   - [Step 5: Smart Card Daemon Setup & Verification](#step-5-smart-card-daemon-setup--verification--libservicesh)
   - [Step 6: Certificate Download with Checksum Validation](#step-6-certificate-download-with-checksum-validation--libcertssh)
   - [Step 7: Browser Detection & Database Discovery](#step-7-browser-detection--database-discovery--libbrowsersh)
   - [Step 8: Certificate Import into Browser NSS Databases](#step-8-certificate-import-into-browser-nss-databases--libimportsh)
   - [Step 9: PKCS11 Module Registration](#step-9-pkcs11-module-registration--libpkcs11sh)
   - [Step 10: Post-Install Verification](#step-10-post-install-verification--libverifysh)
   - [Step 10.5: VMware / Omnissa Horizon Symlink (optional)](#step-105-vmware--omnissa-horizon-symlink-optional)
   - [Step 11: Python Entry Points and Bash Execution Units](#step-11-python-entry-points-and-bash-execution-units)
   - [Step 12: User Documentation](#step-12-user-documentation--readmemd)
4. [Uninstall — `cac_uninstall.py` + `bash/uninstall.sh`](#4-uninstall--cac_uninstallpy--bashuninstallsh)
5. [Testing Strategy](#5-testing-strategy)
6. [Log File Format](#6-log-file-format)
7. [Cross-Reference: Weaknesses to Plan Steps](#7-cross-reference-weaknesses-to-plan-steps)
8. [Phase 2: PyQt6 GUI Application (Placeholder)](#8-phase-2-pyqt6-gui-application-placeholder)
   - [8.1 Installation Dialog](#81-installation-dialog-placeholder)
   - [8.2 Application Loading Splash Screen](#82-application-loading-splash-screen-placeholder)
   - [8.3 App Indicator and Context Menu](#83-app-indicator-and-context-menu-placeholder)
   - [8.4 Main GUI — ActivClient-Style Viewer](#84-main-gui--activclient-style-viewer-placeholder)
9. [Phase 3: GitHub Actions CI/CD](#9-phase-3-github-actions-cicd)
   - [9.1 Platform Constraint: No Arch Linux Runner](#91-platform-constraint-no-arch-linux-runner)
   - [9.2 CI Readiness Contract](#92-ci-readiness-contract)
   - [9.3 Workflow: ci.yml](#93-workflow-ciyml)
   - [9.4 Workflow: release.yml](#94-workflow-releaseyml)
   - [9.5 CI Readiness Annotations in Phase 1](#95-ci-readiness-annotations-in-phase-1)
10. [Phase 4: Quarterly Release Cadence and Issue/PR Management](#10-phase-4-quarterly-release-cadence-and-issuepr-management)
    - [10.0 Overview](#100-overview)
    - [10.1 Release Cadence](#101-release-cadence)
    - [10.2 Issue Intake and Triage](#102-issue-intake-and-triage)
    - [10.3 Pull Request Intake and Evaluation](#103-pull-request-intake-and-evaluation)
    - [10.4 Per-Item Implementation Plan Template](#104-per-item-implementation-plan-template)
    - [10.5 Deep Analysis: Approach to Incorporating External Contributions](#105-deep-analysis-approach-to-incorporating-external-contributions)
11. [Phase 5: Help Guide](#11-phase-5-help-guide)
    - [11.0 Overview](#110-overview)
    - [11.1 Architecture](#111-architecture)
    - [11.2 UI Layout](#112-ui-layout)
    - [11.3 File Layout](#113-file-layout)
    - [11.4 Class and Module Specifications](#114-class-and-module-specifications)
    - [11.5 Help Content Outline](#115-help-content-outline)
    - [11.6 Dependencies](#116-dependencies)
    - [11.7 CI Additions for Phase 5](#117-ci-additions-for-phase-5)
12. [CI/CD Infrastructure Completeness](#12-cicd-infrastructure-completeness)
    - [12.1 Arch Linux Container Job (Correcting Section 9.1)](#121-arch-linux-container-job-correcting-section-91)
    - [12.2 .github/ Directory Structure](#122-github-directory-structure)
    - [12.3 Issue and Pull Request Templates](#123-issue-and-pull-request-templates)
    - [12.4 CODEOWNERS](#124-codeowners)
    - [12.5 Dependabot Configuration](#125-dependabot-configuration)
    - [12.6 Stale Issue and PR Workflow](#126-stale-issue-and-pr-workflow)
    - [12.7 SECURITY.md](#127-securitymd)
    - [12.8 CONTRIBUTING.md](#128-contributingmd)
    - [12.9 CHANGELOG.md Format](#129-changelogmd-format)
    - [12.10 Version Management](#1210-version-management)
    - [12.11 Pre-Commit Hook Configuration](#1211-pre-commit-hook-configuration)
    - [12.12 Python Version Matrix](#1212-python-version-matrix)
    - [12.13 CI Artifact Upload](#1213-ci-artifact-upload)
    - [12.14 Branch Protection Summary](#1214-branch-protection-summary)

---

## 0. Architecture Overview

### 0.1 Three-Layer Model

```
Layer 1 — Python Orchestration (cac_setup.py, orchestrator/)
  Entry point, argument parsing, user interaction, error recovery,
  state management, subprocess lifecycle. Zero knowledge of package
  managers or file paths — those live in Layer 2.

Layer 2 — Distro Abstraction (distros/)
  Routes all distro-specific constants (package names, service units,
  library paths, profile paths) through the correct driver class.
  Adding a new distro = one new directory, one new class, one new
  routing branch. No orchestrator changes required.

Layer 3 — Bash Execution (lib/, bash/)
  Performs all privileged system operations. Invoked by Python as
  subprocesses. Authoritative for: package installation, systemd
  service management, certutil/modutil NSS operations, all file
  operations requiring root.
```

Data flow:
```
sudo python3 cac_setup.py
  → orchestrator/setup_flow.py        (phase sequencer)
      → distros/detect.py             (identifies distro + arch)
          → distros/arch/driver.py    (Arch-specific constants)
      → orchestrator/runner.py        (subprocess wrappers)
          → bash/install.sh [--phase=X]
              → lib/packages.sh, lib/service.sh, lib/certs.sh,
                lib/browser.sh, lib/import.sh, lib/pkcs11.sh,
                lib/verify.sh
      → orchestrator/state.py         (writes /var/lib/cachy_cac/state.json)
      → orchestrator/action_log.py    (writes /var/lib/cachy_cac/action_log.json)
```

### 0.2 Python–Bash Communication Contract

Python calls Bash scripts via `subprocess`. Bash receives distro-specific config as **environment variables** injected by Python. Python scans every line of Bash stdout. A line may match exactly one of three prefix patterns:

- `STATE:<key>=<value>` — updates the in-memory `InstallState` field for `<key>`, then persists to `state.json`. Lines are cumulative (each overwrites the prior value for that key).
- `ACTION:<type>|<field1>|<field2>|...` — creates an `ActionRecord` and appends to `action_log.json`. Lines are append-only audit records. Fields are pipe-delimited; pipes within field values are escaped as `\|`.
- **All other lines** — treated as human-readable progress text; passed through to terminal/log.

A single stdout line may carry only one prefix. Bash exits with a non-zero code on failure. Python captures `returncode`, `stdout`, `stderr` via `BashResult` dataclass and decides whether to abort or continue.

`stream_bash()` in `orchestrator/runner.py` is the **Phase 2 GUI reuse contract** — the GUI calls the same function and consumes the yielded line generator to drive a progress widget. No additional subprocess logic is needed in Phase 2.

**Environment variables injected by Python into every Bash subprocess:**

| Variable | Source | Purpose |
|---|---|---|
| `PKCS11_LIB` | `driver.pkcs11_lib_path` | OpenSC library path (`/usr/lib/opensc-pkcs11.so`) |
| `PCSCD_UNIT` | `driver.pcscd_unit` | Systemd unit name (e.g. `pcscd.socket`) |
| `REAL_USER` | `SUDO_USER` env var | Non-root user context |
| `REAL_HOME` | `getent passwd $REAL_USER` | Non-root home directory |
| `NSS_DB_PATHS` | orchestrator after discovery phase | Colon-separated NSS database paths |
| `STATE_FILE` | constant | `/var/lib/cachy_cac/state.json` |

`NSS_DB_PATHS` is populated by Python after the database discovery phase: Python captures `STATE:nss_databases=...` from the import phase output and injects `NSS_DB_PATHS` as a colon-separated list into all subsequent subprocess calls.

**Variable aliasing in `lib/pkcs11.sh` and `lib/verify.sh`:** These files reference `OPENSC_PKCS11_LIB` rather than `PKCS11_LIB`. To avoid renaming throughout, each of these files declares the alias at the top: `readonly OPENSC_PKCS11_LIB="${PKCS11_LIB}"`. This alias is local to those files; `PKCS11_LIB` remains the canonical injected variable name. All other lib files use `$PKCS11_LIB` directly.

### 0.3 Distro Abstraction — Adding a New Distro

To add support for a new distro (e.g. Fedora), a future developer:

1. Creates `distros/fedora/` directory
2. Creates `distros/fedora/config.py` with all Fedora-specific constants
3. Creates `distros/fedora/driver.py` implementing every method of `DistroDriver` (ABC)
4. Adds one `elif` branch in `distros/detect.py` routing to `FedoraDriver`
5. Does **not** touch `orchestrator/`, `lib/`, or `bash/`

The `distros/debian/driver.py` stub exists from day one so the routing compiles on any system. Future Debian support = implement that class; the routing is already there.

### 0.4 Install/Uninstall Symmetry Contract

Every install action has a documented, explicit uninstall counterpart. The canonical reference is the symmetry table at the top of Section 4. Every developer adding a new install action must add a corresponding row to that table before the code is merged.

State needed for complete reversal is stored in `/var/lib/cachy_cac/state.json` (structured JSON). The state file is written **incrementally** after each phase via an atomic `os.replace()` — if install fails partway through, the uninstall script reverses only what was actually completed.

---

### 0.5 Threading, Cancellation, and Non-Blocking Design

#### 0.5.1 Threading Model

**Rule: the orchestrator is always single-threaded. GUI threads call the orchestrator in a worker thread.**

- **Phase 1 (CLI):** main thread runs the orchestrator sequentially. No background threads needed.
- **Phase 2 (GUI):** a `QThread` worker runs the orchestrator. The main/UI thread never calls the orchestrator directly. Communication uses **Qt signals only**.

```
Main Thread (Qt event loop)           Worker Thread (QThread)
─────────────────────────────         ──────────────────────────
QMainWindow / QWizard                 orchestrator/setup_flow.py
  │  emit(start_signal)  ──────────►  run_setup(driver, sudo_user,
  │                                       cancel_token, progress_cb)
  │  ◄── progress_signal(line) ─────       │
  │  ◄── phase_signal(name) ──────────     │ calls stream_bash()
  │  ◄── error_signal(msg) ───────────     │
  │  ◄── done_signal(ok) ──────────────────┘
  │
  │  on cancel button: cancel_token.set()
```

`orchestrator/worker.py` (Phase 2 file, designed in Phase 1) wraps `InstallerWorker(QThread)` which calls `run_setup()` and emits Qt signals for progress, phase changes, errors, and completion.

#### 0.5.2 Cancellation Architecture

**`orchestrator/cancellation.py`** — `CancellationToken` (wraps `threading.Event`) and `CancellationError` (exception class).

- `cancel_token.check()` is called before every phase in `setup_flow.py`
- `run_bash()` and `stream_bash()` accept `cancel_token`; if set while subprocess is running: `proc.terminate()` → 5s grace period → `proc.kill()` (SIGKILL) → raise `CancellationError`

**Rollback on cancellation:** `setup_flow.py` catches `CancellationError`, calls `run_uninstall(state, driver)` automatically with a fresh token. The user sees rollback progress via the same `progress_cb` stream.

**Cancellation during rollback:** If the user cancels rollback, `run_uninstall()` terminates the same way. The partial state remains in `state.json` + `action_log.json`. The user can manually complete reversal by running `sudo python3 cac_uninstall.py`. The uninstall flow is **idempotent**: each action is marked `reversed=True` in `action_log.json` when complete; subsequent runs skip already-reversed actions.

**Action log integrity:** `action_log.json` writes are atomic — full updated file written to `.tmp` then `os.replace()`. If the process is killed mid-write, the prior complete log is preserved.

#### 0.5.3 Non-Modal UI Rules (Phase 2 — Mandatory)

1. **No `QMessageBox.exec()` during operations.** Use inline status panels and non-blocking notifications. `QMessageBox` only for destructive confirmations *before* an operation starts.
2. **No operations on the main thread.** Any call that may block >50ms goes in a worker thread.
3. **Every operation has a Cancel button**, always enabled, triggering `cancel_token.set()` + automatic rollback.
4. **Progress is always visible** via a non-modal inline log panel (`QPlainTextEdit`) — not a separate progress dialog.
5. **Main window remains interactive** during background operations (card status refresh, cert list reload) via secondary worker threads.

---

### 0.6 Action Log and Comprehensive Audit Trail

#### 0.6.1 Purpose

The action log tracks every individual atomic operation at a granular level — every file touched, every permission set, every certificate imported, every NSS database modified. Together with `state.json`, it enables complete programmatic reversal of every change, post-mortem debugging, and restoration to any prior snapshot.

#### 0.6.2 ActionRecord Schema

**`orchestrator/action_log.py`** — `ActionRecord` dataclass with fields: `timestamp` (Unix float), `action` (typed literal), `target` (primary target path/name), `detail` (dict of action-specific fields), `reversed` (bool, set True when the rollback step executes).

Action-specific `detail` fields:

| `action` | `target` | `detail` keys |
|---|---|---|
| `pkg_install` | package name | `version`, `was_present_before` (bool) |
| `service_enable` | unit name | `was_enabled_before` (bool) |
| `service_start` | unit name | `was_active_before` (bool) |
| `file_download` | destination path | `url`, `sha256`, `size_bytes` |
| `file_extract` | destination dir | `source_archive`, `files_extracted` (list) |
| `file_delete` | file path | `sha256_before`, `permissions_before` |
| `cert_import` | NSS db path | `nickname`, `trust_flags`, `cert_sha256` |
| `cert_remove` | NSS db path | `nickname` |
| `pkcs11_register` | NSS db path | `module_name`, `lib_path` |
| `pkcs11_unregister` | NSS db path | `module_name` |
| `perm_change` | file path | `old_mode`, `new_mode`, `old_owner`, `new_owner` |
| `snapshot_create` | snapshot path | `label`, `cert_count`, `db_count` |
| `snapshot_restore` | snapshot path | `label`, `certs_removed`, `certs_added`, `pkcs11_removed`, `pkcs11_added` |
| `config_change` | setting key | `old_value`, `new_value`, `source` (`"gui"` or `"cli"`) |

Module provides: `append_action(record)` (atomic write + fsync), `load_log() -> list[ActionRecord]`, `mark_reversed(timestamp)`.

#### 0.6.3 Bash-Side ACTION Emission

`lib/import.sh`, `lib/pkcs11.sh`, `lib/packages.sh`, and `lib/service.sh` emit `ACTION:` lines to stdout alongside `STATE:` lines. Python parses them and calls `append_action()`:

```bash
echo "ACTION:cert_import|${db_path}|${nickname}|${trust_flags}|${cert_sha256}"
echo "ACTION:pkcs11_register|${db_path}|CAC Module|${PKCS11_LIB}"
echo "ACTION:pkg_install|${pkg_name}|${pkg_version}|was_present_before=false"
echo "ACTION:service_start|${PCSCD_UNIT}|was_active_before=${was_active}"
```

The human-readable `[ACTION]` tag in `/var/log/cachy_cac_*.log` maps 1:1 to each `ActionRecord` in `action_log.json`.

---

### 0.7 Configuration Snapshots and Config-Only Restore

#### 0.7.1 Snapshot Scope

A snapshot captures **only what the application owns** — never system-level state. Restoring a snapshot never touches packages or services, so other processes depending on pcsclite, OpenSC, etc. are unaffected.

**A snapshot contains:** certificates imported into each NSS database (nicknames + trust flags), PKCS11 registrations (module names + library paths), list of modified NSS databases, metadata (timestamp, label, app version).

**A snapshot does NOT contain:** package install state, service enable/disable state, log files, downloaded certificate files.

#### 0.7.2 Snapshot Storage

`/var/lib/cachy_cac/snapshots/<YYYYMMDD_HHMMSS>/snapshot.json`

Multiple snapshots coexist. No automatic pruning — the user manages them via the GUI.

`orchestrator/snapshot.py` provides `Snapshot` dataclass with `save()`, `load()`, `list_all()`.

#### 0.7.3 Snapshot Operations

- **`create_snapshot(state, label)`** — reads current state from actual NSS databases via `certutil -L -d sql:<path>` and `modutil -dbdir sql:<path> -list` (not just `state.json`, catching drift). Parses `certutil -L` output: each non-header line is `<nickname>  <trust_flags>`. Parses `modutil -list` output: extract `Name:` and `Library file:` fields per module block.

- **`restore_snapshot(snap, driver, cancel_token)`** — diffs snapshot vs current state; removes extra certs/PKCS11 via `bash/uninstall.sh --phase=certs-only` / `--phase=pkcs11-only`; adds missing via `bash/install.sh --phase=certs-only` / `--phase=pkcs11-only`. Logs every action to `action_log.json`. Never touches packages or services.

`--phase=certs-only`: calls `import_all_certs()` (install) or `certutil -D` for each cert (uninstall). No package or service operations.
`--phase=pkcs11-only`: calls `register_pkcs11_all()` (install) or `modutil -delete` (uninstall). No package or service operations.

#### 0.7.4 Config Change History (GUI Undo Stack)

**`orchestrator/config_history.py`** — `ConfigHistory` class with in-memory undo/redo stack (`record()`, `undo()`, `redo()`, `can_undo()`, `can_redo()`). Per-session only — cleared on app restart. Every GUI config change is also logged as `ActionRecord(action="config_change", ...)` to the persistent `action_log.json`.

---

## 1. Source Repository Assessment

### What `linux_cac` Does Well

The `linux_cac` project solves a real and painful problem: DoD CAC support on Linux requires installing several non-obvious packages, importing a large bundle of government CA certificates into browser-specific NSS databases, and wiring up a PKCS11 module so browsers can communicate with the card reader. The script accomplishes all of this in a single invocation with reasonable user-facing messaging. The decision to migrate from CACKey to OpenSC (noted in the README) was architecturally correct — OpenSC is the actively-maintained upstream choice. The `print_info`/`print_err` color convention provides clear feedback. The snap-to-apt Firefox migration, while complex, addresses a genuine Ubuntu-specific breakage that would otherwise silently prevent the setup from working.

### Weaknesses and How This Plan Addresses Them

**W1 — Debian-hardcoded package manager and package names.**
`apt`, `libpcsclite1`, `pcscd`, `libccid`, `libpcsc-perl`, and `libnss3-tools` are all Debian-specific. On Arch/CachyOS the equivalents are `pacman`, `pcsclite` (which bundles the library and daemon), `ccid`, and `nss` (which provides `certutil`). `libpcsc-perl` has no Arch equivalent and is not needed. *Addressed by Step 4.*

**W2 — Hardcoded x86_64 Debian library path.**
The commented-out fallback at line 86–89 of `cac_setup.sh` references `/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so` (Debian multiarch path). On Arch/CachyOS the correct path is `/usr/lib/opensc-pkcs11.so` for both x86_64 and aarch64 (Arch does not use multiarch subdirectories). *Addressed by Steps 2 and 9.*

**W3 — No uninstall script.**
There is no mechanism to reverse the setup, making iterative testing and fresh-install validation impossible. *Addressed by Section 4.*

**W4 — No persistent logging.**
All output goes to stdout/stderr and is lost after the terminal session. Troubleshooting failures is difficult without a record. *Addressed by Step 1.*

**W5 — No certificate download integrity check.**
`wget` is called with no checksum verification. A corrupted or man-in-the-middle download silently produces a broken installation. *Addressed by Step 6.*

**W6 — wget/package-manager failures do not halt the script.**
If package installation or the download fails, the script continues and produces confusing downstream errors. *Addressed throughout all steps via `set -euo pipefail` and explicit error handling.*

**W7 — Race conditions via `sleep 3`.**
`run_firefox` and `run_chrome` use `sleep 3` after launching the browser headlessly. This is unreliable on slow systems. On Arch, Firefox is always a native package; the profile directory appears after a brief headless initialization. This plan replaces `sleep` with a polling loop that waits up to 30 seconds for `cert9.db` to appear. *Addressed by Step 7.*

**W8 — No architecture detection.**
The script would fail on ARM64 without modification. *Addressed by Step 2.*

**W9 — `pkcs11-register` silently fails on CachyOS.**
The `pkcs11-register` binary hardcodes `$HOME/.mozilla/firefox` as the Firefox profile search path. On CachyOS, Firefox stores profiles in `$HOME/.config/mozilla/firefox/`. As a result, `pkcs11-register` finds no Firefox profiles and silently skips them. The source script's own README acknowledges this tool "sometimes does not behave as expected." Our approach uses `modutil` (from the `nss` package) directly against each discovered database as the reliable primary mechanism, and calls `pkcs11-register` as a supplemental best-effort step only. *Addressed by Step 9.*

**W10 — Incomplete browser support.**
Only Firefox and Chrome are handled. On Arch/CachyOS, Chromium (official repos), Microsoft Edge (AUR), and Brave (AUR) are commonly used. All Chromium-based browsers share the `~/.pki/nssdb` NSS database, so one import covers all of them. *Addressed by Step 7.*

**W11 — GNOME-only Firefox pinning with silent failure on other DEs.**
The `check_for_ff_pin`/`repin_firefox` functions exist only to handle the GNOME Favorites bar after the snap-to-apt migration. This is entirely Debian/snap-specific. On Arch, Firefox is always a native pacman package. *Not carried over — irrelevant to Arch/CachyOS.*

**W12 — Certificate trust flags hardcoded without documentation.**
All imported certificates receive `-t TC` with no explanation of what these flags mean. Our implementation documents trust flags explicitly in the source code: `T` = trusted as a CA for SSL/TLS, `C` = trusted CA certificate. *Addressed by Step 8.*

**W13 — No post-install verification step.**
After running the script, there is no way to confirm the CAC is actually detected. The script exits with `EXIT_SUCCESS` regardless. *Addressed by Step 10.*

**W14 — Global variable scope throughout.**
Bash's `local` keyword is used in only one function throughout the source script. Our implementation enforces `local` for all function-scoped variables throughout every module, preventing variable leakage across function calls. *Addressed throughout all modules.*

**W15 — Snap-specific code entirely irrelevant to Arch.**
`reconfigure_firefox`, `backup_ff_profile`, `migrate_ff_profile`, and `revert_firefox` exist only for the Ubuntu snap-vs-apt Firefox distinction. On Arch, Firefox is always installed via pacman. *Not carried over.*

**W16 — Syntax-only CI coverage.**
The CI pipeline runs `shellcheck` only. No functional tests exist. *Addressed by Section 5.*

**W17 — `pcscd.socket` is enabled but never started in the same session.**
`systemctl enable` registers the unit for next boot but does not start it immediately. The source script exits with the smart card daemon inactive until the user reboots. Our implementation adds `systemctl start pcscd.socket` immediately after `enable` so the daemon is operational in the same session. *Addressed by Step 5.*

**W18 — No check that browsers are closed before modifying NSS databases.**
Writing to NSS databases (`cert9.db`, `pkcs11.txt`) while the owning browser process has them open produces silent no-ops or corruption. The source script documents this only in comments. Our implementation performs a programmatic check for running browser processes before any NSS operation and exits with a clear error if any are found. *Addressed by Step 7.*

---

## 2. Project Structure

```
cachy_cac/
├── PLAN.md                  # This document
├── README.md                # User-facing setup instructions
├── KNOWN_ISSUES.md          # Documented test findings
├── LICENSE                  # MIT (same as upstream)
│
├── version.py               # Single version source: __version__ = "0.1.0"
├── cac_setup.py             # Python entry point (replaces cac_setup.sh)
├── cac_uninstall.py         # Python entry point for uninstall
│
├── orchestrator/            # Python orchestration package (Layer 1)
│   ├── __init__.py
│   ├── result.py            # BashResult dataclass (returncode, stdout, stderr, ok)
│   ├── runner.py            # run_bash() + stream_bash() — accept cancel_token
│   ├── state.py             # InstallState dataclass + atomic state.json read/write
│   ├── setup_flow.py        # Ordered install phase sequence (7 phases)
│   ├── uninstall_flow.py    # Symmetric uninstall phase sequence
│   ├── cancellation.py      # CancellationToken + CancellationError
│   ├── action_log.py        # ActionRecord + append_action() + load_log()
│   ├── snapshot.py          # Snapshot + create_snapshot() + restore_snapshot()
│   ├── config_history.py    # ConfigHistory undo/redo stack (Phase 2)
│   └── worker.py            # InstallerWorker QThread (Phase 2)
│
├── distros/                 # Distro abstraction layer (Layer 2)
│   ├── __init__.py
│   ├── base.py              # DistroDriver abstract base class (interface contract)
│   ├── detect.py            # Reads /etc/os-release + uname; returns (DistroInfo, driver)
│   ├── arch/                # Arch/CachyOS driver (Phase 1 — fully implemented)
│   │   ├── __init__.py
│   │   ├── config.py        # All Arch-specific constants
│   │   └── driver.py        # ArchDriver(DistroDriver)
│   └── debian/              # Future — stub only
│       ├── __init__.py
│       └── driver.py        # DebianDriver — raises NotImplementedError
│
├── lib/                     # Bash library modules — sourced by bash/*.sh (Layer 3)
│   ├── log.sh               # Color-coded logging + log file management
│   ├── detect.sh            # validate_env() + detect_root/real_user/tools
│   ├── aur.sh               # AUR helper detection and AUR package installation
│   ├── packages.sh          # Package installation via pacman/AUR — emits STATE: + ACTION:
│   ├── opensc_conf.sh       # OpenSC CAC driver configuration
│   ├── service.sh           # pcscd systemd service management — emits ACTION:
│   ├── certs.sh             # Certificate download, extraction, checksum validation
│   ├── browser.sh           # Browser detection and NSS database discovery
│   ├── import.sh            # Certificate import — emits STATE: + ACTION:
│   ├── pkcs11.sh            # PKCS11 module registration — emits STATE: + ACTION:
│   └── verify.sh            # Post-install verification checks
│
├── bash/                    # Standalone-callable Bash execution units
│   ├── install.sh           # Sources lib/*.sh; dispatched by --phase=X arg
│   └── uninstall.sh         # Sources lib/*.sh; dispatched by --phase=X arg
│
├── tests/
│   ├── test_log.bats
│   ├── test_detect.bats     # Tests validate_env() and detect_to_json()
│   ├── test_aur.bats
│   ├── test_packages.bats
│   ├── test_opensc_conf.bats
│   ├── test_service.bats
│   ├── test_certs.bats
│   ├── test_browser.bats
│   ├── test_import.bats
│   ├── test_pkcs11.bats
│   ├── test_verify.bats
│   ├── helpers/
│   │   └── set_test_env.sh  # Exports all required env vars with Arch defaults for standalone runs
│   ├── integration/         # Skipped in hosted CI; requires real Arch system (CI_INTEGRATION=1)
│   │   └── test_full_install.bats
│   └── test_orchestrator/   # Python unit tests (stdlib unittest)
│       ├── test_runner.py
│       ├── test_state.py
│       ├── test_distro_detect.py
│       ├── test_cancellation.py
│       ├── test_action_log.py
│       ├── test_snapshot.py
│       ├── test_config_history.py
│       └── test_version.py
│
└── gui/                     # Phase 2: PyQt6 GUI Application (planned — not yet implemented)
    ├── __init__.py
    ├── main.py
    ├── installer.py
    ├── splash.py
    ├── indicator.py
    ├── mainwindow.py
    ├── resources/
    │   ├── icons/
    │   └── ui/
    └── requirements.txt
```

> **Note:** The `gui/` directory structure represents the planned Phase 2 layout. Do not create or populate these files until the Phase 2 placeholder section (Section 8) has been replaced with a complete implementation plan.

`lib/` files are sourced only — never executed directly. `bash/install.sh` and `bash/uninstall.sh` are the executable Bash entry points (invoked by Python). `cac_setup.py` and `cac_uninstall.py` are the user-facing entry points. Python scripts use `#!/usr/bin/env python3`; Bash scripts use `#!/bin/bash`. No third-party Python packages required for Phase 1 — standard library only (`subprocess`, `pathlib`, `json`, `dataclasses`, `logging`, `os`, `sys`).

**Execute permissions:** `chmod 750` on `cac_setup.py`, `cac_uninstall.py`, `bash/install.sh`, `bash/uninstall.sh`. Files in `orchestrator/` and `lib/` are imported/sourced modules and do not need execute permissions.

---

## 3. Implementation Steps

### Bash Scripting Standards for This Project

All implementers must follow these conventions consistently. The two main Bash execution units (`bash/install.sh` and `bash/uninstall.sh`) declare `set -euo pipefail` at the top. The Python entry points (`cac_setup.py`, `cac_uninstall.py`) are the user-facing entry points — they are not Bash scripts. All `lib/` files inherit `set -euo pipefail` from the execution unit that sources them.

| Convention | Rule |
|---|---|
| Fail-fast | `set -euo pipefail` at the top of every executable script; library files inherit the setting when sourced |
| Local variables | All function-scoped variables declared with `local varname` or `local varname=value` |
| Constants | Top-level immutable values declared with `readonly` |
| Conditionals | Use `[[ ]]` (Bash extended test); `[ ]` and bare `test` are avoided |
| Arrays | Declare with `arr=()`, append with `arr+=("item")`, expand with `"${arr[@]}"`, count with `${#arr[@]}` |
| Command substitution | Always use `$()`, never backticks |
| Quoting | Always double-quote variable expansions: `"$var"`, `"${arr[@]}"` |
| Script path detection | `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` |
| Background PID | `$!` — works natively in Bash |
| Process PID | `$$` — works natively in Bash |
| Color output | ANSI escape codes via `printf "${RED}...${NC}"` with `readonly` color constants in `lib/log.sh` |
| Unset variable guard | `${VAR:-}` when a variable may be unset; `[[ -n "${VAR:-}" ]]` for presence check |
| log_cmd exit capture | `"$@" >> "$_CAC_LOG_FILE" 2>&1 \|\| s=$?` — the `\|\|` prevents `set -e` from exiting before the status is captured |

**Critical `set -euo pipefail` interaction with `log_cmd`:**
Because `log_cmd` must capture and return the exit status of a potentially failing command without triggering `set -e`, the internal command is placed in a `||` chain:
```bash
"$@" >> "$_CAC_LOG_FILE" 2>&1 || s=$?
```
Callers that expect `log_cmd` to succeed use it in a conditional context so that failures are handled explicitly:
```bash
if ! log_cmd pacman -Syu --noconfirm; then
    log_error "Upgrade failed. Check network connectivity."
    exit "$E_NODEPS"
fi
```

---

### Step 0: Python Orchestration Layer — `orchestrator/`

**What it does.** Provides the top-level control plane. Python is the orchestrator; Bash handles system mutations. `runner.py` wraps subprocess calls to Bash. `state.py` tracks install progress as structured JSON. `setup_flow.py` and `uninstall_flow.py` sequence the 7 phases and make recovery decisions. `cancellation.py` enables mid-operation cancellation with automatic rollback. `action_log.py` maintains the comprehensive audit trail. `snapshot.py` handles config-only snapshots and restore. `config_history.py` provides in-session undo/redo for GUI config changes (Phase 2). `worker.py` is the Phase 2 QThread bridge.

**Files created:** `orchestrator/__init__.py`, `orchestrator/result.py`, `orchestrator/runner.py`, `orchestrator/state.py`, `orchestrator/setup_flow.py`, `orchestrator/uninstall_flow.py`, `orchestrator/cancellation.py`, `orchestrator/action_log.py`, `orchestrator/snapshot.py`, `orchestrator/config_history.py`, `orchestrator/worker.py`

**Key implementation details.**

`result.py` — `BashResult` dataclass:
```python
from dataclasses import dataclass

@dataclass
class BashResult:
    returncode: int
    stdout: str
    stderr: str

    @property
    def ok(self) -> bool:
        return self.returncode == 0
```

`cancellation.py` — `CancellationToken` and `CancellationError`:
```python
import threading

class CancellationError(Exception):
    """Raised when the user requests cancellation."""

class CancellationToken:
    def __init__(self):
        self._event = threading.Event()

    def set(self):
        self._event.set()

    def is_set(self) -> bool:
        return self._event.is_set()

    def check(self):
        """Raise CancellationError if cancellation was requested."""
        if self._event.is_set():
            raise CancellationError("Operation cancelled by user")
```

`runner.py` — two functions, both accepting `cancel_token`:
```python
from pathlib import Path
from typing import Iterator
import subprocess, time
from .result import BashResult
from .cancellation import CancellationToken, CancellationError

def run_bash(script: Path, *args: str, env: dict | None = None,
             cancel_token: CancellationToken | None = None) -> BashResult:
    """Blocking subprocess call. Polls cancel_token every 50ms."""
    with subprocess.Popen(
        ["/bin/bash", str(script), *args],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, env=env
    ) as proc:
        if cancel_token:
            while proc.poll() is None:
                if cancel_token.is_set():
                    proc.terminate()
                    try:
                        proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        proc.kill(); proc.wait()
                    raise CancellationError("Operation cancelled")
                time.sleep(0.05)
        stdout, stderr = proc.communicate()
        return BashResult(proc.returncode, stdout, stderr)

def stream_bash(script: Path, *args: str, env: dict | None = None,
                cancel_token: CancellationToken | None = None) -> Iterator[str]:
    """Yields stdout lines as they arrive. Phase 2 GUI reuse hook."""
    with subprocess.Popen(
        ["/bin/bash", str(script), *args],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, env=env
    ) as proc:
        for line in proc.stdout:
            if cancel_token and cancel_token.is_set():
                proc.terminate()
                try: proc.wait(timeout=5)
                except subprocess.TimeoutExpired: proc.kill(); proc.wait()
                raise CancellationError("Operation cancelled")
            yield line.rstrip()
        proc.wait()
        if proc.returncode != 0:
            raise subprocess.CalledProcessError(proc.returncode, script)
```

`state.py` — `InstallState` dataclass with **atomic** `save()` (writes to `.tmp` then `os.replace()`) and `load()`. Complete field list:
```python
from dataclasses import dataclass, field, asdict
from pathlib import Path
import json, os, time

STATE_DIR = Path("/var/lib/cachy_cac")
STATE_FILE = STATE_DIR / "state.json"

@dataclass
class InstallState:
    version: str = "1"
    distro_id: str = ""
    arch: str = ""
    real_user: str = ""
    install_timestamp: float = 0.0       # Unix time of install start
    last_updated: float = 0.0            # Unix time of last save()
    packages_installed: list[str] = field(default_factory=list)
    pcscd_was_active_before: bool = False   # drives uninstall decision for pcscd
    cert_bundle_sha256: str = ""
    nss_databases: list[str] = field(default_factory=list)
    imported_cert_nicknames: list[str] = field(default_factory=list)  # replaces installed_certs.txt
    pkcs11_registered_in: list[str] = field(default_factory=list)

    def save(self) -> None:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        self.last_updated = time.time()
        tmp = STATE_FILE.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(asdict(self), indent=2))
        os.replace(tmp, STATE_FILE)   # atomic on POSIX

    @classmethod
    def load(cls) -> "InstallState":
        if not STATE_FILE.exists():
            raise FileNotFoundError(f"State file not found: {STATE_FILE}")
        return cls(**json.loads(STATE_FILE.read_text()))
```

`imported_cert_nicknames` is the machine-readable replacement for the prior `installed_certs.txt` manifest. The uninstall flow reads `state.nss_databases` and `state.imported_cert_nicknames` to run `certutil -D -n <nick>` in each database.

`setup_flow.py` — `run_setup(driver, sudo_user, cancel_token=None, progress_cb=None, phase_cb=None)`. Calls `bash/install.sh --phase=X` for each of 7 phases. Before each phase: `cancel_token.check()`. After the packages phase: parse `STATE:` lines to populate `state.packages_installed`. Before service phase: record `pcscd_was_active_before` via `systemctl is-active --quiet`. On `CancellationError`: catch, call `run_uninstall(state, driver)` with a fresh token, re-raise `CancellationError`.

`uninstall_flow.py` — `run_uninstall(state, driver, cancel_token=None, progress_cb=None)`. Idempotent: checks `action_log.json` for already-reversed actions and skips them. Conditionally skips pcscd disable if `state.pcscd_was_active_before`.

**Stdout parsing in `setup_flow.py`:**
```python
for line in result.stdout.splitlines():
    if line.startswith("STATE:"):
        key, _, val = line[6:].partition("=")
        # update InstallState field by key name
    elif line.startswith("ACTION:"):
        parts = line[7:].split("|")
        # construct ActionRecord and call append_action()
    else:
        if progress_cb:
            progress_cb(line)   # forward to terminal or GUI
```

---

### Step 0.5: Distro Abstraction Layer — `distros/`

**What it does.** Identifies the running distro and architecture; returns the matching driver. The orchestrator never hardcodes package names, service units, or library paths — all come from the driver.

**Files created:** `distros/__init__.py`, `distros/base.py`, `distros/detect.py`, `distros/arch/__init__.py`, `distros/arch/config.py`, `distros/arch/driver.py`, `distros/debian/__init__.py`, `distros/debian/driver.py`

**`distros/base.py` — `DistroDriver` abstract base class.** Required methods:

| Method | Return type | Description |
|---|---|---|
| `package_manager` (property) | `str` | Binary name, e.g. `"pacman"` |
| `required_packages` (property) | `list[str]` | All packages to install |
| `smart_card_packages` (property) | `list[str]` | Subset offered for removal on uninstall |
| `pkcs11_lib_path` (property) | `str` | Absolute path to opensc-pkcs11.so |
| `pcscd_unit` (property) | `str` | Systemd unit, e.g. `"pcscd.socket"` |
| `firefox_profile_roots` (property) | `list[str]` | Candidate paths relative to `$HOME` (preference order) |
| `install_packages(packages)` | `list[str]` | Shell command tokens |
| `remove_packages(packages)` | `list[str]` | Shell command tokens |
| `sync_package_db()` | `list[str]` | Shell command tokens |

`DistroInfo` dataclass: `distro_id: str`, `id_like: list[str]`, `arch: str`, `pretty_name: str`.

**`distros/detect.py`** — `detect_distro() -> tuple[DistroInfo, DistroDriver]`:
1. Reads `/etc/os-release` (parse `key=value`, strip quotes)
2. `platform.machine()` for arch
3. Routes by `ID` first, then `ID_LIKE`:
   - `cachyos`, `arch`, `manjaro`, `endeavouros` or `"arch" in id_like` → `ArchDriver`
   - `ubuntu`, `debian`, `linuxmint` or `"debian" in id_like` → `DebianDriver` (raises `NotImplementedError`)
   - Otherwise → `RuntimeError("Unsupported distribution: ...")`

**`distros/arch/config.py`:**
```python
PKCS11_LIB = "/usr/lib/opensc-pkcs11.so"      # unified path: x86_64 and aarch64
PCSCD_UNIT = "pcscd.socket"
REQUIRED_PACKAGES = ["pcsclite", "ccid", "opensc", "nss", "pcsc-tools", "unzip", "wget"]
SMART_CARD_PACKAGES = ["pcsclite", "ccid", "opensc", "pcsc-tools"]
FIREFOX_PROFILE_ROOTS = [".config/mozilla/firefox", ".mozilla/firefox"]
```

**`distros/arch/driver.py`** — `ArchDriver(DistroDriver)`: all properties/methods implemented using `config.py` values. `install_packages` returns `["pacman", "-S", "--needed", "--noconfirm", *packages]`. `sync_package_db` returns `["pacman", "-Syu", "--noconfirm"]`.

**`distros/debian/driver.py`** — `DebianDriver(DistroDriver)`: `__init__` raises `NotImplementedError("Debian/Ubuntu support not yet implemented")`. All abstract methods declared with `raise NotImplementedError` bodies to satisfy the ABC at import time.

**Unit test approach — `tests/test_orchestrator/test_distro_detect.py`:**
1. Mock `/etc/os-release` with CachyOS content → verify `ArchDriver` returned
2. Mock with Ubuntu content → verify `DebianDriver` instantiation raises `NotImplementedError`
3. Mock with unknown distro → verify `RuntimeError` with "Unsupported distribution" message
4. Verify `DistroInfo.arch` equals `platform.machine()` output

---

### Step 1: Logging Infrastructure — `lib/log.sh`

**What it does.**
Provides logging functions (`log_info`, `log_warn`, `log_error`, `log_success`, `log_section`, `log_cmd`) that write color-coded output to the terminal and simultaneously append plain-text records to a persistent log file. `log_init` creates the log file and writes a header. All functions use `local` throughout.

**Files created:** `lib/log.sh`

**Key implementation details.**

Log file path: `/var/log/cachy_cac_YYYYMMDD_HHMMSS.log` — timestamp captured at `log_init` call time using `date +%Y%m%d_%H%M%S`. Path stored in global `_CAC_LOG_FILE`.

Color coding uses ANSI escape codes via `printf` with `readonly` constants so they degrade gracefully when output is redirected.

```bash
#!/bin/bash
# lib/log.sh — Logging infrastructure for cachy_cac

# Guard each readonly to allow safe re-sourcing in BATS (setup() calls source before each test)
[[ -v RED     ]] || readonly RED='\033[0;31m'
[[ -v GREEN   ]] || readonly GREEN='\033[0;32m'
[[ -v YELLOW  ]] || readonly YELLOW='\033[1;33m'
[[ -v CYAN    ]] || readonly CYAN='\033[0;36m'
[[ -v MAGENTA ]] || readonly MAGENTA='\033[0;35m'
[[ -v NC      ]] || readonly NC='\033[0m'

_CAC_LOG_FILE=""

log_init() {
    _CAC_LOG_FILE="/var/log/cachy_cac_$(date +%Y%m%d_%H%M%S).log"
    printf "# cachy_cac log — %s\n" "$(date)" > "$_CAC_LOG_FILE"
    printf "# User: %s — Running as: %s\n" "${SUDO_USER:-}" "$(whoami)" >> "$_CAC_LOG_FILE"
    printf "\n" >> "$_CAC_LOG_FILE"
    log_info "Log file: $_CAC_LOG_FILE"
}

log_info() {
    printf "${YELLOW}[INFO]  ${NC}%s\n" "$*"
    echo "[INFO]  $*" >> "$_CAC_LOG_FILE"
}

log_warn() {
    printf "${MAGENTA}[WARN]  ${NC}%s\n" "$*"
    echo "[WARN]  $*" >> "$_CAC_LOG_FILE"
}

log_error() {
    printf "${RED}[ERROR] ${NC}%s\n" "$*" >&2
    echo "[ERROR] $*" >> "$_CAC_LOG_FILE"
}

log_success() {
    printf "${GREEN}[OK]    ${NC}%s\n" "$*"
    echo "[OK]    $*" >> "$_CAC_LOG_FILE"
}

log_section() {
    local bar="────────────────────────────────────────"
    printf "${CYAN}%s\n  %s\n%s${NC}\n" "$bar" "$*" "$bar"
    printf "%s\n  %s\n%s\n" "$bar" "$*" "$bar" >> "$_CAC_LOG_FILE"
}

log_cmd() {
    # Runs a command, logs its full output to the log file, returns exit status.
    # Usage: log_cmd command arg1 arg2 ...
    # The || pattern prevents set -e from exiting before the status is captured.
    echo "[CMD]   $*" >> "$_CAC_LOG_FILE"
    local s=0
    "$@" >> "$_CAC_LOG_FILE" 2>&1 || s=$?
    echo "[EXIT]  $s" >> "$_CAC_LOG_FILE"
    return "$s"
}
```

`log_cmd` is used for all pacman calls, systemctl operations, certutil invocations, and wget downloads so that complete output is captured even when the terminal only shows a summary message.

**Unit test approach — `tests/test_log.bats`:**
1. Source `lib/log.sh`; call `log_init`; verify `$_CAC_LOG_FILE` exists at the expected path
2. Call `log_info "hello"`; verify the string appears in the log file without ANSI color codes
3. Call `log_cmd true`; verify return code is 0 and `[EXIT]  0` appears in log
4. Call `log_cmd false`; verify return code is 1 and `[EXIT]  1` appears in log
5. Call `log_cmd ls /nonexistent`; verify the error message appears in the log file
6. Call `log_cmd test -f /nonexistent/path` (multi-argument command); verify return code is 1 — this confirms `"$@"` expansion inside `log_cmd` works correctly for multi-token invocations

---

### Step 2: Architecture & Environment Detection — `lib/detect.sh`

**What it does.**
Validates that the script is running as root, identifies the real (sudo-invoking) user and their home directory, validates that required environment variables were injected by the Python orchestrator, checks for required tools, and emits a JSON summary for Python's validation pass. Addresses W2, W8, W14.

**Architecture/OS detection is now handled by Python** (`distros/detect.py`). `lib/detect.sh` no longer exports `SYSTEM_ARCH` or `OPENSC_PKCS11_LIB` — those values arrive as environment variables from Python. This is safe for uninstall: `cac_uninstall.py` calls `detect_distro()` in Python and injects the results before invoking `bash/uninstall.sh`, so `bash/uninstall.sh` receives all required vars via the environment.

**Files created:** `lib/detect.sh`

**Key implementation details.**

Exit codes (readonly):
- `E_NOTROOT=86`, `E_BROWSER=87`, `E_DATABASE=88`, `E_NOARCH=89`, `E_NOTARCH=90`, `E_NODEPS=91`, `E_CONFIG=92`

```bash
#!/bin/bash
# lib/detect.sh — Environment validation for cachy_cac
# OS/arch detection is handled by Python (distros/detect.py).
# This module validates root context, real user, env vars, and required tools.

readonly E_NOTROOT=86
readonly E_BROWSER=87
readonly E_DATABASE=88
readonly E_NOARCH=89
readonly E_NOTARCH=90
readonly E_NODEPS=91
readonly E_CONFIG=92
readonly EXIT_SUCCESS=0

REAL_USER=""
REAL_HOME=""

validate_env() {
    # Asserts that Python injected all required environment variables.
    # Call this before any other function in bash/install.sh or bash/uninstall.sh.
    local required_vars=(PKCS11_LIB PCSCD_UNIT REAL_USER REAL_HOME STATE_FILE)
    for var in "${required_vars[@]}"; do
        [[ -n "${!var:-}" ]] || {
            log_error "Required env var not set: $var (should be injected by Python orchestrator)"
            exit "$E_CONFIG"
        }
    done
    log_info "Environment validated. User: $REAL_USER | Arch lib: $PKCS11_LIB"
}

detect_root() {
    if [[ $(id -u) -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)."
        log_error "Example: sudo python3 cac_setup.py"
        exit "$E_NOTROOT"
    fi
}

detect_real_user() {
    if [[ -z "${REAL_USER:-}" ]]; then
        log_error "REAL_USER not set. Run via: sudo python3 cac_setup.py"
        exit "$E_NOTROOT"
    fi
    if [[ -z "${REAL_HOME:-}" ]]; then
        log_error "REAL_HOME not set. Run via: sudo python3 cac_setup.py"
        exit "$E_NOTROOT"
    fi
    log_info "Configuring for user: $REAL_USER (home: $REAL_HOME)"
}

detect_required_tools() {
    # Phase 1 (pre-install): tools that must exist before packages are installed
    local tool
    for tool in systemctl certutil modutil getent id cut grep find date sha256sum lsmod modprobe; do
        if ! command -v "$tool" > /dev/null 2>&1; then
            log_error "Required tool not found: $tool"
            exit "$E_NODEPS"
        fi
    done
    log_success "All prerequisite tools found."
}

detect_post_install_tools() {
    # Phase 2 (post-install): tools provided by installed packages — call after install_official_packages
    local tool
    for tool in opensc-tool wget unzip; do
        if ! command -v "$tool" > /dev/null 2>&1; then
            log_error "Post-install tool not found: $tool (package installation may have failed)"
            exit "$E_NODEPS"
        fi
    done
    log_success "All post-install tools found."
}

detect_conflicting_modules() {
    # The pn533 and nfc kernel modules are known to conflict with pcscd,
    # preventing reader detection. Unload them if present before pcscd starts.
    # Source: M-Pepper linux-cac-walkthrough
    local mod
    for mod in pn533 nfc; do
        if lsmod 2>/dev/null | grep -q "^${mod} "; then
            log_warn "Conflicting kernel module loaded: $mod — unloading..."
            if modprobe -r "$mod" 2>/dev/null; then
                log_success "Unloaded: $mod"
            else
                log_warn "Could not unload $mod — reader detection may fail"
            fi
        fi
    done
}

detect_to_json() {
    # Emits a single-line JSON object for Python's initial validation pass.
    # Python calls this to confirm Bash sees the injected environment correctly.
    printf '{"arch":"%s","user":"%s","pkcs11_lib":"%s"}\n' \
        "$(uname -m)" "${REAL_USER:-}" "${PKCS11_LIB:-}"
}
```

**`--phase=all` developer escape hatch:** When `bash/install.sh --phase=all` is run directly (without Python), `validate_env()` fails because `PKCS11_LIB`, `PCSCD_UNIT`, `REAL_USER`, `REAL_HOME`, and `STATE_FILE` are not set. Developers must export these vars manually before running standalone. A test wrapper script (`tests/helpers/set_test_env.sh`) is provided for integration testing that exports all required vars with Arch defaults.

**Unit test approach — `tests/test_detect.bats`:**
1. Run `detect_root` as a non-root user; verify it exits with code 86
2. Run as root; verify `detect_real_user` reads `$REAL_USER` and `$REAL_HOME` from env
3. Call `validate_env` with all required vars set; verify no error
4. Call `validate_env` with one var missing; verify exit with `E_CONFIG`
5. Call `detect_to_json`; verify output is valid JSON with keys `arch`, `user`, `pkcs11_lib`

---

### Step 3: AUR Helper Detection — `lib/aur.sh`

**What it does.**
Detects whether `paru` or `yay` is available and provides an `aur_install` wrapper. Used for AUR packages such as `google-chrome`, `microsoft-edge-stable-bin`, and `brave-bin`. Handles the critical requirement that AUR helpers **must not be run as root** by delegating to `sudo -u $REAL_USER`. Addresses W1 (partial).

**Files created:** `lib/aur.sh`

**Key implementation details.**

Detection preference: `paru` first (CachyOS default), then `yay`. Populates global `$_AUR_HELPER`.

```bash
#!/bin/bash
# lib/aur.sh — AUR helper detection and package installation

_AUR_HELPER=""

detect_aur_helper() {
    if command -v paru > /dev/null 2>&1; then
        _AUR_HELPER="paru"
        log_info "AUR helper: paru"
    elif command -v yay > /dev/null 2>&1; then
        _AUR_HELPER="yay"
        log_info "AUR helper: yay"
    else
        _AUR_HELPER=""
        log_warn "No AUR helper found. AUR packages (Google Chrome, Edge, Brave) cannot be installed."
        log_warn "Install paru or yay, then re-run if those browsers are needed."
    fi
}

aur_install() {
    # Usage: aur_install <package_name>
    # AUR helpers refuse to run as root; drop to real user via sudo -u
    local pkg="$1"
    if [[ -z "$_AUR_HELPER" ]]; then
        log_warn "Cannot install AUR package $pkg: no AUR helper available."
        return 1
    fi
    log_info "Installing AUR package: $pkg (as $REAL_USER)"
    local s=0
    sudo -H -u "$REAL_USER" "$_AUR_HELPER" -S --noconfirm "$pkg" >> "$_CAC_LOG_FILE" 2>&1 || s=$?
    if [[ $s -ne 0 ]]; then
        log_warn "Failed to install AUR package: $pkg (non-fatal, continuing)"
        return $s
    fi
    log_success "AUR package installed: $pkg"
    return 0
}
```

**Unit test approach — `tests/test_aur.bats`:**
1. Verify `detect_aur_helper` sets `$_AUR_HELPER` to `paru` when paru is present
2. Temporarily hide paru from PATH; verify fallback to `yay`
3. Hide both; verify `$_AUR_HELPER` is empty and warning is logged
4. Verify `aur_install` returns 1 gracefully when `$_AUR_HELPER` is empty

---

### Step 4: Package Installation — `lib/packages.sh`

**What it does.**
Installs required packages via `pacman`, checking whether each is already installed first to make the script re-entrant. Fails fast with a clear error if `pacman -Syu` or `pacman -S` fails. After installation, verifies `certutil` is on the PATH. Addresses W1, W6.

**Files created:** `lib/packages.sh`

**Key implementation details.**

Required packages and purposes:

| Package | Replaces (Debian) | Purpose |
|---|---|---|
| `pcsclite` | `libpcsclite1` + `pcscd` | PC/SC middleware library and daemon |
| `ccid` | `libccid` | USB CCID smart card reader driver |
| `opensc` | `opensc` | OpenSC tools, `opensc-pkcs11.so`, `pkcs11-register` |
| `nss` | `libnss3-tools` | NSS library + `certutil` + `modutil` |
| `pcsc-tools` | `pcsc-tools` | Diagnostic tools (`pcsc_scan`) |
| `unzip` | `unzip` | Extract the AllCerts.zip bundle |
| `wget` | `wget` | Download the AllCerts.zip bundle |

Note: `libpcsc-perl` (Debian) has no Arch equivalent and is not needed.

```bash
#!/bin/bash
# lib/packages.sh — Package installation

# MAINTENANCE NOTE: REQUIRED_PACKAGES is also defined in distros/arch/config.py.
# Both lists must be kept in sync. The Bash list is the executable authority;
# the Python list is used for pre-flight validation before Bash runs.
readonly REQUIRED_PACKAGES=(pcsclite ccid opensc nss pcsc-tools unzip wget)

is_package_installed() {
    pacman -Qi "$1" > /dev/null 2>&1
}

install_official_packages() {
    log_section "Package Installation"
    # IMPORTANT: On Arch/CachyOS (a rolling-release distro), using `pacman -Sy`
    # without `-u` is explicitly warned against in the Arch Wiki as a "partial upgrade"
    # that can break the system. Always use `pacman -Syu` (sync + full upgrade first)
    # before installing new packages. This ensures the package database and installed
    # packages are consistent before adding new dependencies.
    log_info "Syncing package database and upgrading system..."
    if ! log_cmd pacman -Syu --noconfirm; then
        log_error "System sync/upgrade failed. Check network connectivity."
        exit "$E_NODEPS"
    fi

    local to_install=()
    local pkg
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if is_package_installed "$pkg"; then
            log_info "Already installed: $pkg"
        else
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "Installing packages: ${to_install[*]}"
        if ! log_cmd pacman -S --needed --noconfirm "${to_install[@]}"; then
            log_error "Package installation failed. See log: $_CAC_LOG_FILE"
            exit "$E_NODEPS"
        fi
        log_success "Packages installed: ${to_install[*]}"
    else
        log_success "All required packages already present."
    fi
}

verify_certutil() {
    if ! command -v certutil > /dev/null 2>&1; then
        log_error "certutil not found after installing nss. Try: pacman -S nss"
        exit "$E_NODEPS"
    fi
    if ! command -v modutil > /dev/null 2>&1; then
        log_error "modutil not found after installing nss. Try: pacman -S nss"
        exit "$E_NODEPS"
    fi
    log_success "certutil and modutil found: $(command -v certutil)"
}
```

**Unit test approach — `tests/test_packages.bats`:**
1. With all packages installed, verify script logs "Already installed" and makes no extra `pacman -S` call
2. Remove a test package (e.g. `pcsc-tools`); verify it gets re-installed
3. Verify `pacman -Syu` is called (not `-Sy` alone) — check log for the correct flags
4. After install, run `verify_certutil` and confirm both `certutil` and `modutil` are found

---

### Step 4.5: OpenSC Configuration — `lib/opensc_conf.sh`

**What it does.**
Ensures `/etc/opensc/opensc.conf` explicitly forces the CAC driver. Without this,
some systems fail to recognise the CAC card even when the reader is detected. Also
calls `detect_conflicting_modules()` (from `detect.sh`) to unload `pn533`/`nfc`
kernel modules before `pcscd` starts. Identified as a common failure point on
Debian-based systems; worth applying proactively on Arch as a defensive measure.
Source: M-Pepper linux-cac-walkthrough.

**Files created:** `lib/opensc_conf.sh`

**Key implementation details.**

```bash
#!/bin/bash
# lib/opensc_conf.sh — OpenSC CAC driver configuration

OPENSC_CONF="/etc/opensc/opensc.conf"

configure_opensc_cac_driver() {
    log_section "OpenSC Configuration"

    if [[ ! -f "$OPENSC_CONF" ]]; then
        log_warn "$OPENSC_CONF not found — skipping (opensc may not be installed yet)"
        return 0
    fi

    # Check if already configured
    if grep -q "force_card_driver" "$OPENSC_CONF" 2>/dev/null; then
        log_info "OpenSC CAC driver forcing already configured."
        return 0
    fi

    log_info "Adding CAC driver forcing to $OPENSC_CONF..."
    # Append inside the app default block if present, otherwise append at end
    if grep -q "app default {" "$OPENSC_CONF"; then
        sed -i '/app default {/a\\tcard_drivers = cac;\n\tforce_card_driver = cac;' "$OPENSC_CONF"
    else
        printf '\napp default {\n\tcard_drivers = cac;\n\tforce_card_driver = cac;\n}\n' \
            >> "$OPENSC_CONF"
    fi
    log_success "OpenSC CAC driver forcing configured."
}
```

**Unit test approach — `tests/test_opensc_conf.bats`:**
1. With an unmodified `opensc.conf`, run `configure_opensc_cac_driver`; confirm `force_card_driver = cac` appears
2. Run a second time; confirm idempotency (no duplicate entries)
3. With `opensc.conf` absent, confirm function warns and exits cleanly (non-fatal)

---

### Step 5: Smart Card Daemon Setup & Verification — `lib/service.sh`

**What it does.**
Enables and starts `pcscd.socket` (socket-activated service, correct for Arch), verifies it enters active state, and provides `disable_pcscd` for use by the uninstall script. Addresses W17.

**Files created:** `lib/service.sh`

**Key implementation details.**

On Arch/CachyOS, `pcscd` uses socket activation. `pcscd.socket` must be enabled/started; `pcscd.service` starts automatically on first smart card reader access.

```bash
#!/bin/bash
# lib/service.sh — pcscd service management

enable_pcscd() {
    log_section "Smart Card Daemon"
    if ! log_cmd systemctl enable pcscd.socket; then
        log_error "Failed to enable pcscd.socket"
        exit 1
    fi
    if ! log_cmd systemctl start pcscd.socket; then
        log_error "Failed to start pcscd.socket"
        exit 1
    fi
    log_success "pcscd.socket enabled and started."
}

verify_pcscd_service() {
    # Returns 0 if active, non-zero otherwise
    systemctl is-active --quiet pcscd.socket
}

disable_pcscd() {
    # Used by uninstall script
    log_info "Stopping and disabling pcscd..."
    systemctl stop pcscd.socket pcscd.service 2>/dev/null || true
    systemctl disable pcscd.socket 2>/dev/null || true
    log_success "pcscd disabled."
}
```

**Unit test approach — `tests/test_service.bats`:**
1. Run `enable_pcscd`; confirm `systemctl is-active pcscd.socket` returns "active"
2. Run `verify_pcscd_service`; confirm return code 0
3. Manually stop the socket; confirm `verify_pcscd_service` returns non-zero
4. Run `disable_pcscd`; confirm the unit is neither active nor enabled

---

### Step 6: Certificate Download with Checksum Validation — `lib/certs.sh`

**What it does.**
Downloads `AllCerts.zip` from militarycac.com, computes and logs its SHA-256 hash, warns loudly if it differs from the stored baseline (but does not abort, since DoD periodically updates the bundle), and extracts `.cer` files to a PID-unique staging directory. Registers `cleanup_certs` for the uninstall path. Addresses W5, W6.

**Files created:** `lib/certs.sh`

**Key implementation details.**

`$$` (process PID) works natively in Bash and is used to create a unique staging directory:
```bash
DWNLD_DIR="/tmp/cachy_cac_$$"
```

`mapfile` (a Bash built-in) safely populates an array from `find` output, handling filenames with spaces correctly:
```bash
mapfile -t CERT_FILES < <(find "$dest" -name "*.cer" -type f)
```

```bash
#!/bin/bash
# lib/certs.sh — Certificate download, validation, and extraction

readonly CERT_URL="https://militarycac.com/maccerts/AllCerts.zip"
readonly BUNDLE_NAME="AllCerts.zip"
readonly CERT_DIR_NAME="AllCerts"
DWNLD_DIR="/tmp/cachy_cac_$$"
# Known-good SHA-256 of AllCerts.zip (update after each bundle refresh)
# Run: sha256sum AllCerts.zip to obtain the current hash
# Set to "" to skip hash check (warn but continue)
KNOWN_CERT_SHA256=""
CERT_FILES=()

download_certs() {
    log_section "Certificate Download"
    mkdir -p "$DWNLD_DIR"
    log_info "Downloading DoD certificate bundle from: $CERT_URL"
    if ! log_cmd wget -q --show-progress -P "$DWNLD_DIR" "$CERT_URL"; then
        log_error "Download failed. Check network connectivity."
        cleanup_certs
        exit 1
    fi
    log_success "Downloaded: $DWNLD_DIR/$BUNDLE_NAME"
}

validate_cert_bundle() {
    log_info "Validating certificate bundle integrity..."
    local actual_sha
    actual_sha="$(sha256sum "$DWNLD_DIR/$BUNDLE_NAME" | cut -d' ' -f1)"
    log_info "SHA-256: $actual_sha"
    if [[ -n "$KNOWN_CERT_SHA256" ]]; then
        if [[ "$actual_sha" == "$KNOWN_CERT_SHA256" ]]; then
            log_success "Checksum verified."
        else
            log_warn "Checksum mismatch! Expected: $KNOWN_CERT_SHA256"
            log_warn "Actual: $actual_sha"
            log_warn "This may indicate an updated bundle. Update KNOWN_CERT_SHA256 in lib/certs.sh after verifying."
        fi
    else
        log_warn "No baseline checksum configured — skipping integrity check."
        log_warn "Populate KNOWN_CERT_SHA256 in lib/certs.sh after first successful download."
    fi
}

extract_certs() {
    log_info "Extracting certificate bundle..."
    local dest="$DWNLD_DIR/$CERT_DIR_NAME"
    mkdir -p "$dest"
    if ! log_cmd unzip -q "$DWNLD_DIR/$BUNDLE_NAME" -d "$dest"; then
        log_error "Extraction failed."
        cleanup_certs
        exit 1
    fi
    mapfile -t CERT_FILES < <(find "$dest" -name "*.cer" -type f)
    local count=${#CERT_FILES[@]}
    if [[ $count -eq 0 ]]; then
        log_error "No .cer files found after extraction."
        cleanup_certs
        exit 1
    fi
    log_success "Extracted $count certificate files."
}

cleanup_certs() {
    log_info "Cleaning up staging directory: $DWNLD_DIR"
    if rm -rf "$DWNLD_DIR"; then
        log_success "Staging directory removed."
    else
        log_warn "Could not remove $DWNLD_DIR — remove manually if needed."
    fi
}
```

**Unit test approach — `tests/test_certs.bats`:**
1. Run `download_certs`; verify `$DWNLD_DIR/AllCerts.zip` exists and is non-empty
2. Compute SHA-256 manually; set `KNOWN_CERT_SHA256`; re-run `validate_cert_bundle`; confirm "Checksum verified"
3. Truncate the zip; verify `extract_certs` fails with a clear error
4. Run `cleanup_certs`; verify `$DWNLD_DIR` is removed

---

### Step 7: Browser Detection & Database Discovery — `lib/browser.sh`

**What it does.**
Detects installed browsers (Firefox, Chromium, Google Chrome, Microsoft Edge, Brave), discovers their NSS database directories, initializes the shared Chromium NSS database if missing, and polls for Firefox profile creation using a reliable loop instead of `sleep`. Populates `$NSS_DATABASES` array for import and registration steps. Addresses W7, W10.

**Files created:** `lib/browser.sh`

**Key implementation details.**

**Critical CachyOS difference:** Firefox on CachyOS stores profiles in `$HOME/.config/mozilla/firefox/`, not `$HOME/.mozilla/firefox/`. Both paths are searched to handle edge cases.

**Chromium-based browsers** (Chrome, Chromium, Edge, Brave) all use the single shared NSS database at `$HOME/.pki/nssdb`. One import covers all of them simultaneously.

**`$!`:** Bash stores the PID of the last backgrounded process in `$!` — assign it immediately after the `&` to prevent it from being overwritten.

**NSS ownership rule (critical):** All `certutil` and `modutil` operations against user-owned NSS databases **must** be run as `$REAL_USER` via `sudo -H -u "$REAL_USER"`, never directly as root. If root creates or modifies a user's NSS database, the resulting files are owned by root and become unreadable by the browser running as the regular user, silently breaking CAC authentication. This rule applies in `browser.sh`, `import.sh`, and `pkcs11.sh` without exception.

```bash
#!/bin/bash
# lib/browser.sh — Browser detection and NSS database discovery

NSS_DATABASES=()
FF_FOUND=false
CHROMIUM_ANY_FOUND=false

check_browsers_closed() {
    # Browsers must be closed before we modify their NSS databases.
    # Writing cert9.db or pkcs11.txt while a browser holds the file open
    # produces silent corruption or no-ops. Fail fast with a clear message.
    local running_browsers
    running_browsers="$(pgrep -x -E "firefox|chromium|google-chrome|microsoft-edge|brave" 2>/dev/null || true)"
    if [[ -n "$running_browsers" ]]; then
        log_error "Browser processes are running. Close all browsers before running this script."
        log_error "Detected PIDs: $running_browsers"
        log_error "Run: pkill firefox chromium google-chrome microsoft-edge brave"
        exit 1
    fi
    log_success "No browser processes detected."
}

_ensure_firefox_profile() {
    # Poll for cert9.db — no arbitrary sleep
    local ff_db
    ff_db="$(find "$REAL_HOME/.config/mozilla/firefox" \
                  "$REAL_HOME/.mozilla/firefox" \
                  -name cert9.db 2>/dev/null | grep -v Trash | head -1 || true)"
    if [[ -z "$ff_db" ]]; then
        log_info "Initializing Firefox profile (headless)..."
        sudo -H -u "$REAL_USER" firefox --headless --first-startup > /dev/null 2>&1 &
        local ff_pid=$!
        local waited=0
        while [[ $waited -lt 30 ]]; do
            ff_db="$(find "$REAL_HOME/.config/mozilla/firefox" \
                          "$REAL_HOME/.mozilla/firefox" \
                          -name cert9.db 2>/dev/null | grep -v Trash | head -1 || true)"
            [[ -n "$ff_db" ]] && break
            sleep 0.5
            (( waited++ ))
        done
        kill "$ff_pid" 2>/dev/null || true
        if [[ -z "$ff_db" ]]; then
            log_warn "Firefox profile not created after 30s. Open Firefox manually, close it, and re-run."
            return 1
        fi
    fi
    log_success "Firefox profile found: $(dirname "$ff_db")"
    return 0
}

check_for_firefox() {
    log_info "Checking for Firefox..."
    if command -v firefox > /dev/null 2>&1; then
        FF_FOUND=true
        log_success "Firefox: $(command -v firefox)"
        _ensure_firefox_profile
    else
        log_info "Firefox not installed."
    fi
}

check_for_chromium_browsers() {
    log_info "Checking for Chromium-based browsers..."
    local found_count=0
    local browser
    for browser in google-chrome chromium microsoft-edge-stable brave; do
        if command -v "$browser" > /dev/null 2>&1; then
            log_success "Found: $browser"
            (( found_count++ ))
        fi
    done
    [[ $found_count -gt 0 ]] && CHROMIUM_ANY_FOUND=true
}

_ensure_nssdb() {
    local nssdb="$REAL_HOME/.pki/nssdb"
    if [[ ! -d "$nssdb" ]]; then
        log_info "Creating shared Chromium NSS database at: $nssdb"
        sudo -H -u "$REAL_USER" mkdir -p "$nssdb"
        if ! sudo -H -u "$REAL_USER" certutil -d sql:"$nssdb" -N --empty-password; then
            log_error "Failed to initialize NSS database at $nssdb"
            return 1
        fi
        log_success "NSS database created: $nssdb"
    else
        log_info "NSS database exists: $nssdb"
    fi
}

discover_databases() {
    log_section "Browser and Database Discovery"
    check_browsers_closed
    check_for_firefox
    check_for_chromium_browsers

    if [[ "$FF_FOUND" == false ]] && [[ "$CHROMIUM_ANY_FOUND" == false ]]; then
        log_error "No supported browsers found."
        log_error "Install Firefox, Chromium, Google Chrome, Microsoft Edge, or Brave."
        exit "$E_BROWSER"
    fi

    NSS_DATABASES=()

    # Firefox databases (search both possible profile roots)
    local ff_db db_dir
    while IFS= read -r ff_db; do
        db_dir="$(dirname "$ff_db")"
        log_info "Firefox NSS database: $db_dir"
        NSS_DATABASES+=("$db_dir")
    done < <(find "$REAL_HOME/.config/mozilla/firefox" \
                  "$REAL_HOME/.mozilla/firefox" \
                  -name cert9.db 2>/dev/null | grep -v Trash || true)

    # Chromium-based browser shared database
    if [[ "$CHROMIUM_ANY_FOUND" == true ]]; then
        _ensure_nssdb
        if [[ -d "$REAL_HOME/.pki/nssdb" ]]; then
            log_info "Chromium NSS database: $REAL_HOME/.pki/nssdb"
            NSS_DATABASES+=("$REAL_HOME/.pki/nssdb")
        fi
    fi

    if [[ ${#NSS_DATABASES[@]} -eq 0 ]]; then
        log_error "No cert9.db databases found. Open each browser once, close it, and re-run."
        exit "$E_DATABASE"
    fi

    log_success "Discovered ${#NSS_DATABASES[@]} NSS database(s)."
}
```

**Unit test approach — `tests/test_browser.bats`:**
1. With Firefox installed and profile present, verify `$NSS_DATABASES` includes the correct `~/.config/mozilla/firefox/<profile>` path
2. With only Chromium installed, verify `$NSS_DATABASES` includes `~/.pki/nssdb`
3. Remove `~/.pki/nssdb`; verify `_ensure_nssdb` creates it owned by `$REAL_USER` (not root), with a valid `cert9.db`
4. Verify `discover_databases` exits with `E_BROWSER` when no browsers are installed
5. Verify the polling loop terminates within 30s if Firefox is slow to initialize
6. Verify `check_browsers_closed` exits with a clear error when Firefox is running, and passes when no browsers are active

---

### Step 8: Certificate Import into Browser NSS Databases — `lib/import.sh`

**What it does.**
For each discovered NSS database directory, imports all `.cer` files from the extracted bundle using `certutil`. Skips certificates already present. Reports per-cert success/failure without aborting on individual failures (some certs may already exist or be formatted unexpectedly). Addresses W12.

**Files created:** `lib/import.sh`

**Key implementation details.**

**Trust flag documentation:**
`-t TC` = `T` (trusted CA for SSL/TLS server certificate verification) + `C` (trusted CA certificate).
This is the correct trust level for DoD root CAs to enable CAC authentication. Operators with stricter trust policies may change this to `-t C,C,` (trusted CA only) or `-t ,C,` (CA but not trusted for auth) per their security requirements.

**NSS ownership rule:** All `certutil` calls use `sudo -H -u "$REAL_USER"` (see Step 7 note). Never run `certutil` as root against user-owned NSS databases.

**Certificate tracking:** After each successful `certutil -A` call, the Bash function emits a `STATE:` line. Python parses it and appends the nickname to `state.imported_cert_nicknames`, which is persisted to `state.json` after the import phase. The uninstall flow reads `state.imported_cert_nicknames` for exact-match removal via `certutil -D`.

```bash
#!/bin/bash
# lib/import.sh — Certificate import into NSS databases

import_certs_into_db() {
    # Usage: import_certs_into_db <db_dir>
    local db_dir="$1"
    local label="NSS database"
    [[ "$db_dir" == *mozilla* ]] || [[ "$db_dir" == *firefox* ]] && label="Firefox"
    [[ "$db_dir" == *pki* ]] && label="Chromium (shared)"

    log_section "Importing certificates — $label"
    log_info "Database: $db_dir"

    local imported=0 skipped=0 failed=0
    local cert_file cert_name

    # Import ordering: root CAs must precede intermediates so the chain
    # validates correctly during import. Sort by depth — root CAs are
    # self-signed (issuer == subject); intermediates chain to a root.
    # Pragmatic approach: sort CERT_FILES alphabetically by basename.
    # DoD bundle names roots as "DoD_Root_CA_*" and intermediates as "DoD_CA_*",
    # so lexicographic order naturally places roots first.
    # Source: Ubuntu community CAC wiki
    local sorted_cert_files
    mapfile -t sorted_cert_files < <(printf '%s\n' "${CERT_FILES[@]}" | sort -t/ -k4,4)

    for cert_file in "${sorted_cert_files[@]}"; do
        cert_name="$(basename "$cert_file")"

        # Check if cert already exists — run as real user; root cannot read user-owned NSS db
        if sudo -H -u "$REAL_USER" certutil -d sql:"$db_dir" -L -n "$cert_name" > /dev/null 2>&1; then
            (( skipped++ ))
            continue
        fi

        # Trust flags: TC = trusted CA for SSL/TLS + trusted CA certificate
        # Run as real user — NSS databases are owned by $REAL_USER, not root
        local s=0
        sudo -H -u "$REAL_USER" certutil \
            -d sql:"$db_dir" \
            -A -t "TC" \
            -n "$cert_name" \
            -i "$cert_file" >> "$_CAC_LOG_FILE" 2>&1 || s=$?
        if [[ $s -eq 0 ]]; then
            (( imported++ ))
            echo "STATE:imported_cert_nicknames+=$cert_name"
        else
            (( failed++ ))
            log_warn "  Failed to import: $cert_name (non-fatal)"
        fi
    done

    log_success "$label: imported=$imported skipped=$skipped failed=$failed"
    if [[ $failed -gt 0 ]]; then
        log_warn "  $failed failure(s) — review log: $_CAC_LOG_FILE"
    fi
}

import_all_certs() {
    log_section "Certificate Import"
    if [[ ${#CERT_FILES[@]} -eq 0 ]]; then
        log_error "No certificate files available. Run extract_certs first."
        exit 1
    fi
    local db_dir
    for db_dir in "${NSS_DATABASES[@]}"; do
        import_certs_into_db "$db_dir"
    done
    log_success "Certificate import phase complete."
}
```

**Unit test approach — `tests/test_import.bats`:**
1. Import into a fresh `~/.pki/nssdb`; run `certutil -d sql:~/.pki/nssdb -L`; confirm DoD CA names appear
2. Run `import_all_certs` a second time; verify all certs are skipped ("Already present")
3. Plant a corrupt `.cer` among valid ones; verify failure is reported and remaining certs still import
4. Verify Firefox profile database also contains the imported certs

---

### Step 9: PKCS11 Module Registration — `lib/pkcs11.sh`

**What it does.**
Registers the OpenSC PKCS11 module with each NSS database using `modutil`. Also calls `pkcs11-register` as a supplemental best-effort step. The critical insight here is that `pkcs11-register` silently fails for Firefox on CachyOS (it searches `~/.mozilla/firefox` but Firefox is at `~/.config/mozilla/firefox`); `modutil` is the reliable primary mechanism. Addresses W2, W9.

**Files created:** `lib/pkcs11.sh`

**Key implementation details.**

**`modutil` vs `certutil`:** PKCS11 module registration uses `modutil`, not `certutil`. `certutil` handles certificate records; `modutil` handles PKCS11 provider module records written to `pkcs11.txt`. Both binaries are in the `nss` package.

```bash
#!/bin/bash
# lib/pkcs11.sh — PKCS11 module registration

readonly PKCS11_MODULE_NAME="CAC Module"

cleanup_legacy_pkcs11() {
    # Remove stale cackey/coolkey entries from NSS databases before registering
    # OpenSC. Leftover entries from prior install attempts cause silent auth
    # failures — the browser finds the old (missing) library first and stops.
    # Source: M-Pepper linux-cac-walkthrough
    local db_dir="$1"
    local legacy_name
    for legacy_name in "CAC Module" "CACKey" "coolkey" "libcoolkeypk11"; do
        if sudo -H -u "$REAL_USER" modutil -dbdir sql:"$db_dir" -list 2>/dev/null | grep -qi "$legacy_name"; then
            log_info "Removing legacy PKCS11 entry '$legacy_name' from: $db_dir"
            sudo -H -u "$REAL_USER" modutil \
                -dbdir sql:"$db_dir" \
                -delete "$legacy_name" \
                -force >> "$_CAC_LOG_FILE" 2>&1 || true
        fi
    done
}

register_pkcs11_in_db() {
    # Usage: register_pkcs11_in_db <db_dir>
    local db_dir="$1"

    # Check if already registered — run as real user; root cannot read user-owned NSS db
    if sudo -H -u "$REAL_USER" modutil -dbdir sql:"$db_dir" -list 2>/dev/null | grep -qi "opensc-pkcs11"; then
        log_info "OpenSC module already registered in: $db_dir"
        return 0
    fi

    log_info "Registering OpenSC PKCS11 module in: $db_dir"
    # -force suppresses the interactive "restart browser" prompt
    local s=0
    sudo -H -u "$REAL_USER" modutil \
        -dbdir sql:"$db_dir" \
        -add "$PKCS11_MODULE_NAME" \
        -libfile "$OPENSC_PKCS11_LIB" \
        -force >> "$_CAC_LOG_FILE" 2>&1 || s=$?
    if [[ $s -ne 0 ]]; then
        log_warn "modutil returned $s for: $db_dir — see log"
        return $s
    fi
    log_success "Registered PKCS11 module in: $db_dir"
}

register_pkcs11_all() {
    log_section "PKCS11 Module Registration"
    log_info "PKCS11 library: $OPENSC_PKCS11_LIB"

    if [[ ! -f "$OPENSC_PKCS11_LIB" ]]; then
        log_error "OpenSC PKCS11 library not found: $OPENSC_PKCS11_LIB"
        log_error "Ensure opensc is installed: pacman -S opensc"
        exit 1
    fi

    local db_dir
    for db_dir in "${NSS_DATABASES[@]}"; do
        register_pkcs11_in_db "$db_dir"
    done

    # pkcs11-register as supplemental step:
    # Works for ~/.pki/nssdb but silently misses Firefox on CachyOS
    # because it hardcodes ~/.mozilla/firefox as the profile search path.
    # The modutil calls above handle Firefox correctly via NSS_DATABASES.
    if command -v pkcs11-register > /dev/null 2>&1; then
        log_info "Running pkcs11-register (supplemental — may warn about Firefox path)..."
        sudo -H -u "$REAL_USER" pkcs11-register >> "$_CAC_LOG_FILE" 2>&1 || true
        log_info "pkcs11-register completed (non-zero exit is expected on CachyOS for Firefox)."
    fi
}
```

**Unit test approach — `tests/test_pkcs11.bats`:**
1. After `register_pkcs11_all`, run `modutil -dbdir sql:~/.pki/nssdb -list`; confirm "CAC Module" with `/usr/lib/opensc-pkcs11.so`
2. Check the Firefox profile database: `modutil -dbdir sql:<ff_profile> -list`; confirm "CAC Module"
3. Run `register_pkcs11_all` twice; confirm idempotency (second run skips already-registered)
4. Verify with a non-existent `$OPENSC_PKCS11_LIB` path; confirm script exits with an error
5. Inspect `pkcs11.txt` in both databases to confirm `library=/usr/lib/opensc-pkcs11.so`

---

### Step 10: Post-Install Verification — `lib/verify.sh`

**What it does.**
Checks that `pcscd.socket` is active, the PKCS11 module is registered in all databases, DoD CA certificates are present in all databases, and (if hardware is present) a card reader is detected. Provides overall pass/warn summary. Addresses W13.

**Files created:** `lib/verify.sh`

**Key implementation details.**

```bash
#!/bin/bash
# lib/verify.sh — Post-install verification

verify_pcscd() {
    log_info "pcscd.socket status..."
    if verify_pcscd_service; then
        log_success "pcscd.socket is active."
        return 0
    else
        log_error "pcscd.socket is NOT active."
        return 1
    fi
}

verify_pkcs11_registered() {
    log_info "Verifying PKCS11 module registration..."
    local ok=0 bad=0
    local db_dir
    for db_dir in "${NSS_DATABASES[@]}"; do
        if sudo -H -u "$REAL_USER" modutil -dbdir sql:"$db_dir" -list 2>/dev/null | grep -qi "opensc-pkcs11"; then
            log_success "  Registered: $db_dir"
            (( ok++ ))
        else
            log_error "  NOT registered: $db_dir"
            (( bad++ ))
        fi
    done
    [[ $bad -eq 0 ]]
}

verify_certificates_imported() {
    log_info "Verifying certificates in NSS databases..."
    local db_dir count
    for db_dir in "${NSS_DATABASES[@]}"; do
        count="$(certutil -d sql:"$db_dir" -L 2>/dev/null | wc -l)"
        if [[ $count -gt 10 ]]; then
            log_success "  $count cert(s) found in: $db_dir"
        else
            log_warn "  Only $count cert(s) in: $db_dir — import may have failed"
        fi
    done
}

verify_card_reader() {
    log_info "Checking for connected card reader..."
    if command -v opensc-tool > /dev/null 2>&1; then
        local output
        output="$(opensc-tool --list-readers 2>&1 || true)"
        if [[ -n "$output" ]]; then
            if [[ "$output" == *"No smart card"* ]]; then
                log_warn "Reader driver active but no CAC inserted."
            else
                log_success "Card reader detected: $output"
            fi
        else
            log_info "No readers detected — insert your CAC reader and verify with: opensc-tool --list-readers"
        fi
    fi
}

verify_card_objects() {
    # Confirm the CAC is readable through OpenSC by listing PKCS11 objects.
    # Requires a physical CAC to be inserted — skipped with a warning if not.
    # Source: Derrekito linux-cac-setup
    if ! command -v pkcs11-tool > /dev/null 2>&1; then
        log_info "pkcs11-tool not available — skipping card object check"
        return 0
    fi
    log_info "Listing CAC objects via pkcs11-tool..."
    local output
    output="$(sudo -H -u "$REAL_USER" pkcs11-tool \
        --module "$OPENSC_PKCS11_LIB" \
        --list-objects 2>&1 || true)"
    if echo "$output" | grep -qi "Certificate\|Private Key\|Public Key"; then
        log_success "CAC objects readable through OpenSC PKCS11."
        log_info "$output"
    elif echo "$output" | grep -qi "no token\|no card\|token not present"; then
        log_warn "No CAC inserted — insert card and re-run verification to confirm."
    else
        log_warn "pkcs11-tool returned unexpected output — review log: $_CAC_LOG_FILE"
        log_info "$output"
    fi
}

run_verification() {
    log_section "Post-Install Verification"
    local ok=true
    verify_pcscd || ok=false
    verify_pkcs11_registered || ok=false
    verify_certificates_imported
    verify_card_reader

    if [[ "$ok" == true ]]; then
        log_success "All critical verification checks passed."
        log_info "Recommendation: Reboot before first use."
    else
        log_warn "Some checks failed — review: $_CAC_LOG_FILE"
        log_warn "A reboot may still resolve these issues."
    fi
}
```

**Unit test approach — `tests/test_verify.bats`:**
1. After full setup, run `run_verification`; confirm all checks pass
2. Stop `pcscd.socket` manually; confirm `verify_pcscd` reports failure
3. Delete the PKCS11 module with `modutil -delete`; confirm `verify_pkcs11_registered` fails
4. With a physical CAC reader attached, confirm `verify_card_reader` reports reader name
5. With CAC inserted, run `verify_card_objects`; confirm Certificate/Key objects appear

---

### Step 10.5: VMware / Omnissa Horizon Symlink *(optional)*

**What it does.**
Creates a symlink so the Horizon thin client can find the OpenSC PKCS11 library.
Horizon ships its own pkcs11 directory and does not read the system NSS databases.
Applies only if a Horizon installation is detected. Source: M-Pepper linux-cac-walkthrough.

**Key implementation details.**

```bash
#!/bin/bash
# Optional step — only runs if Horizon is installed

VMWARE_HORIZON_PKCS11="/usr/lib/vmware/view/pkcs11/libopenscpkcs11.so"
OMNISSA_HORIZON_PKCS11="/usr/lib/omnissa/horizon/pkcs11/libopenscpkcs11.so"

configure_horizon_symlink() {
    log_section "VMware/Omnissa Horizon PKCS11 (optional)"
    local target="$OPENSC_PKCS11_LIB"
    local link

    for link in "$VMWARE_HORIZON_PKCS11" "$OMNISSA_HORIZON_PKCS11"; do
        local link_dir
        link_dir="$(dirname "$link")"
        if [[ -d "$link_dir" ]]; then
            if [[ -L "$link" ]]; then
                log_info "Horizon symlink already exists: $link"
            else
                ln -s "$target" "$link"
                log_success "Created Horizon symlink: $link -> $target"
            fi
        fi
    done
}
```

> **Known issue:** If a virtual machine is actively passing through the CAC
> reader, the host loses reader access ("token unavailable"). Suspend or
> disconnect the VM's USB passthrough before running setup or using the CAC
> on the host. Source: Ubuntu community CAC wiki.

---

### Future Feature: PAM Login Integration (`pam_pkcs11`)

> **Not in scope for Phase 1.** Document here for Phase 2 planning.

Using the CAC for Linux system login requires `pam_pkcs11`. Key details from the
Ubuntu community CAC wiki:

- **Subject mapping** uses the DoD DN format:
  `/C=US/O=U.S. Government/OU=DoD/OU=PKI/OU=<branch>/CN=LASTNAME.FIRSTNAME.MI.DODID`
- **Config file:** `/etc/pam_pkcs11/pam_pkcs11.conf` — set `use_pkcs11_module = opensc`
  and `cert_policy = signature`
- **PAM stack:** Add to `/etc/pam.d/system-auth` or `/etc/pam.d/login`
- **Arch package:** `pam_pkcs11` is available in the AUR

This is distinct from browser/portal authentication and requires careful PAM stack
configuration to avoid locking the user out. Must be gated behind explicit user
opt-in and tested with a recovery path.

---

### Step 11: Python Entry Points and Bash Execution Units

**What it does.**
`cac_setup.py` and `cac_uninstall.py` are the user-facing entry points. They perform minimal work: check root, detect distro, and delegate to the orchestrator. `bash/install.sh` and `bash/uninstall.sh` are the Bash execution units invoked by Python via subprocess with `--phase=X` dispatch. The 7-phase structure mirrors the original setup flow and is visible in both terminal output and the log file. Addresses W6.

**Files created:** `cac_setup.py`, `cac_uninstall.py`, `bash/install.sh`, `bash/uninstall.sh`

**`cac_setup.py`:**
```python
#!/usr/bin/env python3
# Usage: sudo python3 cac_setup.py
# All browsers must be closed before running.
import sys, os
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from orchestrator.setup_flow import run_setup
from distros.detect import detect_distro

def main():
    if os.geteuid() != 0:
        print("[ERROR] Run with sudo: sudo python3 cac_setup.py", file=sys.stderr)
        sys.exit(86)
    sudo_user = os.environ.get("SUDO_USER", "")
    if not sudo_user:
        print("[ERROR] SUDO_USER not set. Run: sudo python3 cac_setup.py", file=sys.stderr)
        sys.exit(86)
    try:
        distro_info, driver = detect_distro()
    except RuntimeError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        sys.exit(1)
    print(f"[INFO]  Detected: {distro_info.pretty_name} ({distro_info.arch})")
    print(f"[INFO]  User: {sudo_user}")
    run_setup(driver=driver, sudo_user=sudo_user)

if __name__ == "__main__":
    main()
```

**`cac_uninstall.py`:** See Section 4 for the authoritative `cac_uninstall.py` code skeleton and full implementation details.

**`bash/install.sh`** — Bash execution unit. Sources all `lib/*.sh` and dispatches by `--phase` arg. Receives all distro config as environment variables from Python:
```bash
#!/bin/bash
# bash/install.sh — CAC install execution unit.
# Called by cac_setup.py via orchestrator/runner.py.
# All distro-specific values arrive as environment variables from Python.
# Do NOT add orchestration logic here — Python is the orchestrator.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE="${1:---phase=all}"

for lib_file in log detect aur packages opensc_conf service certs browser import pkcs11 verify; do
    source "$SCRIPT_DIR/lib/$lib_file.sh"
done

validate_env
log_init

case "$PHASE" in
    --phase=preflight)
        log_section "Phase 1: Pre-flight Checks"
        detect_root; detect_real_user; detect_required_tools; check_browsers_closed ;;
    --phase=packages)
        log_section "Phase 2: Package Installation"
        detect_aur_helper; install_official_packages; verify_certutil; detect_post_install_tools ;;
    --phase=opensc-conf)
        log_section "Phase 2.5: OpenSC Configuration"
        configure_opensc_cac_driver ;;
    --phase=service)
        log_section "Phase 3: Smart Card Daemon"
        enable_pcscd ;;
    --phase=certs)
        log_section "Phase 4: Certificate Download"
        download_certs; validate_cert_bundle; extract_certs ;;
    --phase=import)
        log_section "Phase 5: Browser and Certificate Setup"
        discover_databases; import_all_certs ;;
    --phase=pkcs11)
        log_section "Phase 6: PKCS11 Module Registration"
        register_pkcs11_all ;;
    --phase=verify)
        log_section "Phase 7: Cleanup and Verification"
        cleanup_certs; run_verification ;;
    --phase=certs-only)
        # Snapshot restore: import only, no packages/services
        import_all_certs ;;
    --phase=pkcs11-only)
        # Snapshot restore: PKCS11 only, no packages/services
        register_pkcs11_all ;;
    --phase=all|all)
        # Developer escape hatch: run all phases without Python.
        # REQUIRES: export PKCS11_LIB PCSCD_UNIT REAL_USER REAL_HOME STATE_FILE before running.
        # See tests/helpers/set_test_env.sh for a test wrapper.
        log_section "CachyOS CAC Setup (standalone mode)"
        detect_root; detect_real_user; detect_required_tools; check_browsers_closed
        detect_aur_helper; install_official_packages; verify_certutil; detect_post_install_tools
        configure_opensc_cac_driver
        enable_pcscd; download_certs; validate_cert_bundle; extract_certs
        discover_databases; import_all_certs; register_pkcs11_all
        cleanup_certs; run_verification ;;
    *)
        echo "[ERROR] Unknown phase: $PHASE" >&2; exit 1 ;;
esac
```

`bash/uninstall.sh` mirrors this structure with uninstall-phase equivalents (cert removal, PKCS11 unregistration, pcscd disable, package removal).

**Unit test approach (integration):**
1. Run `sudo python3 cac_setup.py` end-to-end on a clean CachyOS system; verify all 7 phases complete and exit 0
2. Verify `state.json` exists at `/var/lib/cachy_cac/state.json` with all fields populated
3. Verify `action_log.json` contains `ActionRecord` entries for every install action
4. Verify the log file exists at `/var/log/cachy_cac_*.log` and contains the full session
5. Run `sudo python3 cac_uninstall.py`; verify all state is reversed and `state.json` is removed

---

### Step 12: User Documentation — `README.md`

**What it does.**
Creates the user-facing `README.md` for `cachy_cac/` that serves as the entry point for anyone cloning the project from scratch. This is a tracked deliverable, not an afterthought.

**Files created:** `README.md`

**Required content outline:**

```markdown
# cachy_cac — CachyOS CAC Setup

Configure CachyOS for DoW Common Access Card (CAC) authentication in Firefox,
Chromium, Google Chrome, Microsoft Edge, and Brave.

## Prerequisites
- CachyOS (or any Arch-based Linux distribution)
- `sudo` access with `SUDO_USER` set (run via `sudo python3`, not `sudo su`)
- All browsers closed before running

## Installation
\`\`\`bash
sudo python3 cac_setup.py
\`\`\`

## Post-Install Verification
After rebooting:
\`\`\`bash
opensc-tool --list-readers    # Confirm card reader detected
\`\`\`
Then open a browser and navigate to a CAC-protected site (e.g., https://my.af.mil).
You should be prompted to select your CAC certificate.

## Uninstallation / Fresh Install Testing
\`\`\`bash
sudo python3 cac_uninstall.py
\`\`\`
This reverses all changes and returns the system to pre-CAC state,
ready for a fresh install test from a clean clone.

## Troubleshooting
- See `/var/log/cachy_cac_*.log` for the full install log
- If pcscd is not running: `systemctl start pcscd.socket`
- If certificate dialog does not appear: reboot first, then retry
- Known issues: see `KNOWN_ISSUES.md`

## Differences from upstream linux_cac
See the Assessment section of `PLAN.md` for a full comparison.
```

**Unit test approach:** Verify the file exists at `cachy_cac/README.md` and contains the minimum required sections (Prerequisites, Installation, Uninstallation). A `grep` for each section header in a CI step is sufficient.

---

## 4. Uninstall — `cac_uninstall.py` + `bash/uninstall.sh`

### Install/Uninstall Symmetry Table

Every install action has a documented, explicit uninstall counterpart. Every developer adding a new install action must add a corresponding row to this table before the PR is accepted.

| # | Install Action | Uninstall Action | State Field |
|---|---|---|---|
| 1 | `pacman -Syu` + install `required_packages` | `pacman -Rs` packages in `smart_card_packages` ∩ `packages_installed` (user-prompted; skip general-purpose packages like `wget`, `unzip`) | `state.packages_installed` — only packages not already present before install |
| 2 | `systemctl enable pcscd.socket && systemctl start pcscd.socket` | `systemctl stop pcscd.socket pcscd.service && systemctl disable pcscd.socket` — **only if `pcscd_was_active_before == False`** | `state.pcscd_was_active_before` — captured by Python before the service phase |
| 3 | Download `AllCerts.zip` → extract `.cer` to `/tmp/cachy_cac_$$` | Temp dir removed at end of install phase via `cleanup_certs` — no persistent uninstall action needed | N/A |
| 4 | `certutil -A -t TC -n <nickname> -i <cert_file>` in each NSS database | `certutil -D -n <nickname>` in each database listed in `nss_databases` | `state.nss_databases` + `state.imported_cert_nicknames` |
| 5 | `modutil -add "CAC Module" -libfile <pkcs11_lib>` in each NSS database | `modutil -delete "CAC Module"` in each database listed in `pkcs11_registered_in` | `state.pkcs11_registered_in` |
| 6 | `pkcs11-register` (supplemental, best-effort) | No uninstall action — `modutil -delete` above covers the databases it registered with; `pkcs11-register` has no "unregister" command | N/A |
| 7 | Modify `/etc/opensc/opensc.conf` to add `card_drivers = cac` and `force_card_driver = cac` | Remove the added block from `/etc/opensc/opensc.conf` (restore backup if one was saved; otherwise remove the appended block) | `state.opensc_conf_modified: bool` |
| 8 | Create Horizon symlinks (`/usr/lib/vmware/view/pkcs11/libopenscpkcs11.so`, `/usr/lib/omnissa/horizon/pkcs11/libopenscpkcs11.so`) — **only if Horizon is installed** | Remove symlinks if they were created by this tool — skip if the Horizon directory no longer exists | `state.horizon_symlinks_created: list[str]` |
| 9 | Create `/var/lib/cachy_cac/state.json` | Delete `/var/lib/cachy_cac/state.json` and directory (user-prompted) | N/A |
| 10 | Create `/var/log/cachy_cac_*.log` | Delete `/var/log/cachy_cac_*.log` (user-prompted) | N/A |

**Purpose:** Completely reverse all changes made by `cac_setup.py`. Designed to be run before fresh-install testing. All browsers must be closed before running. The uninstall script is safe to run multiple times (all operations are idempotent — each `ActionRecord` in `action_log.json` is marked `reversed=True` once completed; subsequent runs skip already-reversed actions).

**What it reverses:**
1. Checks that browsers are closed (calls `check_browsers_closed` from `lib/browser.sh`)
2. Removes the OpenSC PKCS11 module registration from all NSS databases (`modutil -delete`) — databases listed in `state.pkcs11_registered_in`
3. Removes DoD CA certificates from all NSS databases using `state.imported_cert_nicknames` for exact-match removal
4. Stops and disables `pcscd.socket` and `pcscd.service` — **only if `state.pcscd_was_active_before == False`**
5. Optionally removes installed packages (prompted — only packages in `state.packages_installed` ∩ `smart_card_packages`)
6. Optionally removes log files at `/var/log/cachy_cac_*.log` and state directory at `/var/lib/cachy_cac/` (prompted)
7. Verifies clean state

**Key implementation details.**

`cac_uninstall.py` — Python entry point:
```python
#!/usr/bin/env python3
# Usage: sudo python3 cac_uninstall.py
import sys, os
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from orchestrator.uninstall_flow import run_uninstall
from orchestrator.state import InstallState
from distros.detect import detect_distro

def main():
    if os.geteuid() != 0:
        print("[ERROR] Run with sudo: sudo python3 cac_uninstall.py", file=sys.stderr)
        sys.exit(86)
    try:
        state = InstallState.load()
    except FileNotFoundError:
        print("[ERROR] No state file at /var/lib/cachy_cac/state.json")
        print("        If installed manually, see README.md for manual uninstall steps")
        sys.exit(1)
    _, driver = detect_distro()
    run_uninstall(state=state, driver=driver)

if __name__ == "__main__":
    main()
```

`bash/uninstall.sh` — thin execution unit sourcing all lib files, dispatched by `--phase=X`. Mirrors `bash/install.sh` structure:
```bash
#!/bin/bash
# Called by cac_uninstall.py. Do NOT add orchestration logic here.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE="${1:---phase=all}"
for lib_file in log detect service browser import pkcs11 packages verify; do
    source "$SCRIPT_DIR/lib/$lib_file.sh"
done
validate_env; log_init
case "$PHASE" in
    --phase=preflight)   detect_root; detect_real_user; check_browsers_closed ;;
    --phase=pkcs11)      unregister_pkcs11_all ;;
    --phase=certs)       remove_all_certs ;;
    --phase=service)     disable_pcscd ;;
    --phase=packages)    remove_smart_card_packages ;;
    --phase=cleanup)     remove_state_and_logs ;;
    --phase=verify)      run_uninstall_verification ;;
    --phase=certs-only)  remove_all_certs ;;
    --phase=pkcs11-only) unregister_pkcs11_all ;;
    --phase=all|all)    # Developer escape hatch — runs entire uninstall without Python
        detect_root; detect_real_user; check_browsers_closed
        unregister_pkcs11_all; remove_all_certs
        disable_pcscd; remove_smart_card_packages
        remove_state_and_logs; run_uninstall_verification ;;
    *) echo "[ERROR] Unknown phase: $PHASE" >&2; exit 1 ;;
esac
```

The `--phase=all` mode is a **developer escape hatch** — requires the same manual env var exports as `bash/install.sh --phase=all`.

**Certificate removal:** `certutil -D` requires an exact nickname match. The primary removal mechanism uses `state.imported_cert_nicknames` from `/var/lib/cachy_cac/state.json`, which records the exact nickname of every certificate imported during setup. The uninstall flow is idempotent: `certutil -D` on a nickname that no longer exists is treated as "already removed" (logged as a warning; execution continues).

---

## 5. Testing Strategy

### Unit Test Structure — BATS (Bash Automated Testing System)

All test files live in `tests/` with the `.bats` extension. BATS is installed via the `bash-bats` package from the Arch community repository. BATS provides TAP-format output, CI integration, and a clean `@test` / `run` / `setup` / `teardown` structure.

```bash
#!/usr/bin/env bats
# tests/test_log.bats

setup() {
    # Source the library under test; log to a temp file
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "$SCRIPT_DIR/lib/log.sh"
    # Override log path for tests to avoid needing root
    _CAC_LOG_FILE="$(mktemp)"
}

teardown() {
    rm -f "$_CAC_LOG_FILE"
}

@test "log_init creates log file at expected path" {
    # Reset to real path so log_init sets it
    unset _CAC_LOG_FILE
    log_init
    [[ -f "$_CAC_LOG_FILE" ]]
}

@test "log_info writes message to log file without ANSI codes" {
    log_info "hello"
    grep -q "\[INFO\]  hello" "$_CAC_LOG_FILE"
}

@test "log_cmd returns 0 for a succeeding command" {
    run log_cmd true
    [ "$status" -eq 0 ]
}

@test "log_cmd returns 1 for a failing command" {
    run log_cmd false
    [ "$status" -eq 1 ]
}

@test "log_cmd captures error output in log file" {
    log_cmd ls /nonexistent_path_xyz 2>/dev/null || true
    grep -q "\[EXIT\]  2" "$_CAC_LOG_FILE"
}

@test "log_cmd expands multi-token commands correctly" {
    run log_cmd test -f /nonexistent/path
    [ "$status" -eq 1 ]
}
```

Key BATS conventions used throughout:
- `setup()` — runs before each `@test`; sources libraries, creates temp files
- `teardown()` — runs after each `@test`; removes temp files
- `run <command>` — executes a command and captures `$status` and `$output` without triggering `set -e`
- `[ "$status" -eq N ]` — checks exit code
- `[[ "$output" == *pattern* ]]` — checks stdout output

### Python Unit Tests — `tests/test_orchestrator/`

Tests use stdlib `unittest` (no pytest required for Phase 1):

- **`test_runner.py`**: mock a Bash script exiting 0 → `BashResult.ok == True`; mock exit 1 → `BashResult.ok == False`; verify `stream_bash` yields lines in order; verify env vars are passed to subprocess; verify cancellation terminates subprocess and raises `CancellationError`
- **`test_state.py`**: `InstallState` round-trip (save → load → equal); `save()` creates `STATE_DIR` if missing; `load()` raises `FileNotFoundError` when absent; `save()` is atomic (writes to `.tmp` then renames)
- **`test_distro_detect.py`**: mock `/etc/os-release` with CachyOS content → `ArchDriver` returned; mock Ubuntu content → `DebianDriver` raises `NotImplementedError`; mock unknown distro → `RuntimeError`
- **`test_cancellation.py`**: `CancellationToken` starts unset; `set()` makes `is_set()` True; `check()` raises `CancellationError` when set; `check()` is no-op when unset
- **`test_action_log.py`**: `append_action()` writes to file; `load_log()` round-trips; `mark_reversed()` sets `reversed=True` on matching record; concurrent appends do not corrupt the file
- **`test_snapshot.py`**: `create_snapshot()` calls `certutil -L` and `modutil -list` (mocked); `save()`/`load()` round-trip; `list_all()` returns snapshots sorted by timestamp; `restore_snapshot()` diffs correctly (adds missing, removes extra)
- **`test_config_history.py`**: `record()` then `undo()` returns the change; `undo()` on empty returns None; `redo()` after `undo()` re-applies; `record()` clears redo stack

### Integration Test Outline

**Test environment:** CachyOS installation (bare metal or VM snapshot restorable to clean state).

1. **Snapshot** clean system before any CAC setup.
2. Run `sudo python3 cac_setup.py`; record exit code and log path.
3. Run `verify.sh` functions directly; confirm pcscd active, modules registered, certs present.
4. Open Firefox; navigate to a CAC-protected site (e.g., `https://my.af.mil`); confirm certificate selection dialog appears.
5. Open Chromium; confirm the same CAC selection dialog.
6. *(If hardware available)* Insert CAC; run `opensc-tool --list-readers`; confirm reader and card detected.
7. Run `sudo python3 cac_uninstall.py`; verify clean state.
8. Restore snapshot; repeat from step 2 after any code change.

### Fresh Install Testing Workflow

The uninstall entry point enables a rapid code-fix-retest cycle **without** requiring a VM snapshot for every iteration:

```
sudo python3 cac_setup.py        # Install
# Test and find a bug
# Fix the code
sudo python3 cac_uninstall.py    # Remove all changes
sudo python3 cac_setup.py        # Re-install from clean state
# Verify fix
```

**Priority note:** Complete and verify `cac_uninstall.py` before completing `cac_setup.py`. A correct uninstall script is the prerequisite for a reliable test cycle.

### Documenting Issues

Maintain `cachy_cac/KNOWN_ISSUES.md` with entries in this format:

```markdown
## Issue #N: [Short title]
**Date found:** YYYY-MM-DD
**Step/Function:** Step N — function_name()
**Symptom:** What was observed
**Root cause:** Why it happened
**Fix applied:** What changed in which file
**Verified fixed by:** Test that confirms resolution
```

### CI Recommendations *(deprecated — see Sections 9.3 and 12.1)*

> **Deprecated — superseded by Sections 9.3 and 12.1.** The skeleton below was an early draft and is preserved for historical context only. Do not implement from this block. The canonical CI plan is in Section 9.3 (`ci.yml` skeleton with five jobs, correct `working-directory`, `workflow_call` trigger, and Python matrix) and Section 12.1 (Arch container `bats-arch` job). Note: this draft used `pacman -Sy` (a forbidden partial upgrade — see Section 3 Bash standards); the corrected form in Section 12.1 uses `pacman -Syu`.

```yaml
# .github/workflows/CI.yml  ← DEPRECATED; see Section 9.3 and 12.1
name: CI
on: [push, pull_request]
jobs:
  syntax:
    runs-on: ubuntu-latest
    container: archlinux:latest
    steps:
      - uses: actions/checkout@v4
      - run: pacman -Sy --noconfirm bash shellcheck  # ← FORBIDDEN: use pacman -Syu
      - run: bash -n lib/*.sh bash/install.sh bash/uninstall.sh
      - run: shellcheck lib/*.sh bash/install.sh bash/uninstall.sh
  unit-tests:
    runs-on: ubuntu-latest
    container: archlinux:latest
    steps:
      - uses: actions/checkout@v4
      - run: pacman -Sy --noconfirm bash bash-bats nss pcsclite opensc
      - run: bats tests/test_log.bats
      # Additional test scripts as they are created
  python-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: python3 -m unittest discover -s tests/test_orchestrator -v
  python-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install ruff mypy && ruff check orchestrator/ distros/ cac_setup.py cac_uninstall.py
```

---

## 6. Log File Format

### Location

`/var/log/cachy_cac_YYYYMMDD_HHMMSS.log`

A new file is created for each run (setup or uninstall). The path is printed to the terminal at startup. Previous logs are preserved for comparison.

### Log Entry Format

| Tag | Terminal Color | When Used |
|---|---|---|
| `[INFO]` | Yellow | General status messages |
| `[WARN]` | Bright Magenta | Non-fatal issues requiring attention |
| `[ERROR]` | Red | Fatal errors that halt the script |
| `[OK]` | Green | Successful step completion |
| `[CMD]` | *(file only)* | Full command executed via `log_cmd` |
| `[EXIT]` | *(file only)* | Exit code of each `log_cmd` invocation |
| `[ACTION]` | *(file only)* | Every atomic reversible action: cert import/remove, PKCS11 register/unregister, package install, service state change, file download, permission change |

Every `[ACTION]` entry in the log file maps 1:1 to an `ActionRecord` in `/var/lib/cachy_cac/action_log.json`. The log file provides human-readable summaries; the JSON provides machine-parseable data for programmatic reversal.

### What is Logged

The following operations are logged as `[ACTION]` entries (and persisted as `ActionRecord` entries in `action_log.json`):

- Every `certutil -A` or `certutil -D` call: NSS db path, certificate nickname, trust flags
- Every `modutil -add` or `modutil -delete` call: NSS db path, module name, library path
- Every `pacman -S` install: package name, version installed, whether it was already present before
- Every `systemctl enable/start/stop/disable`: unit name, state before and after
- Every `wget` download: URL, destination path, SHA256 of downloaded file
- Every file extracted from a ZIP: destination path, permissions set
- Every permission change (`chmod`/`chown`): path, before mode/owner, after mode/owner

### Accessing Logs

```bash
# Most recent log
cat "$(ls -t /var/log/cachy_cac_*.log | head -1)"

# All logs
ls -lh /var/log/cachy_cac_*.log

# Errors and warnings only
grep -E "\[ERROR\]|\[WARN\]" "$(ls -t /var/log/cachy_cac_*.log | head -1)"
```

Log files are written by root but world-readable (permissions `0644`) so the regular user can inspect them without sudo.

---

## 7. Cross-Reference: Weaknesses to Plan Steps

| Weakness | Addressed By |
|---|---|
| W1: Debian-hardcoded packages/package manager | Step 4 (`packages.sh`) |
| W2: Hardcoded x86_64 Debian library path | Steps 2 (`detect.sh`) + 9 (`pkcs11.sh`) |
| W3: No uninstall script | Section 4 (`cac_uninstall.py` + `bash/uninstall.sh`) |
| W4: No persistent logging | Step 1 (`log.sh`) |
| W5: No certificate integrity check | Step 6 (`certs.sh`) |
| W6: Failures don't halt the script | All steps (`set -euo pipefail` + explicit error handling) |
| W7: Race conditions with `sleep` | Step 7 (`browser.sh` — polling loop) |
| W8: No architecture detection | Step 2 (`detect.sh`) |
| W9: `pkcs11-register` silent failure on CachyOS | Step 9 (`pkcs11.sh` — `modutil` primary, `pkcs11-register` supplemental) |
| W10: No Chromium/Edge/Brave support | Step 7 (`browser.sh`) |
| W11: GNOME-only Firefox pinning | Not carried over (Arch-irrelevant) |
| W12: Trust flags undocumented | Step 8 (`import.sh` — documented inline) |
| W13: No post-install verification | Step 10 (`verify.sh`) |
| W14: Global variable scope | All modules (enforced `local` throughout all functions) |
| W15: Snap-specific code | Not carried over (Arch-irrelevant) |
| W16: Syntax-only CI | Section 5 (BATS unit tests + `shellcheck` in CI) |
| W17: `pcscd.socket` enabled but not started | Step 5 (`service.sh` — adds `systemctl start`) |
| W18: No browser-closed check | Step 7 (`browser.sh` — `check_browsers_closed` function) |
| W-New-1: No distro abstraction — Bash hardcodes Arch assumptions | `distros/` layer — `distros/arch/config.py` holds all Arch constants; `distros/base.py` defines the driver interface; adding Debian = implement `DebianDriver` only |
| W-New-2: Incomplete install/uninstall state (plaintext cert manifest only) | `orchestrator/state.py` — JSON state tracks every reversible action; `pcscd_was_active_before` ensures correct pcscd uninstall behavior |
| W-New-3: No Python orchestration layer — Phase 2 GUI has no reusable backend | `orchestrator/runner.stream_bash()` is the shared reuse hook; both CLI and Phase 2 GUI consume the same yielded line generator |

---

## 8. Phase 2: PyQt6 GUI Application (Placeholder)

> ⚠️ **This entire section is a placeholder.** Do not begin Phase 2 implementation
> until Phase 1 (Bash script backend) is fully complete, tested, and verified on a
> real CachyOS system. When ready to plan Phase 2, provide requirements to Claude
> and request a full implementation plan for each subsection below.

### Overview

Phase 2 wraps the Phase 1 orchestration layer in a PyQt6 graphical application.
The GUI application will:

- Call `orchestrator.runner.stream_bash(bash_dir / 'install.sh')` and consume the
  yielded line stream to drive the progress view. No new subprocess logic is needed
  in Phase 2 — `stream_bash()` is the shared reuse hook from Phase 1.
- Provide a resident system tray indicator that shows CAC/reader status and allows
  the user to open the main window or trigger setup/uninstall without a terminal.
- Present a main window in the style of ActivClient (HID Global's DoD smart card
  manager) showing certificate details, reader status, and card identity information
  read via OpenSC/PKCS11.
- Ship a self-contained installer so non-technical users can deploy the full tool
  without interacting with the command line.

**Threading requirement (mandatory for Phase 2):** All orchestrator operations run
in a `QThread` worker (`orchestrator/worker.py`). The main window thread never calls
`run_setup()`, `run_uninstall()`, `create_snapshot()`, or `restore_snapshot()`
directly. Communication uses Qt signals only (see Section 0.5.1 for the full thread
boundary diagram and `InstallerWorker` class).

**Non-modal requirement (mandatory for Phase 2):** No `QMessageBox.exec()` or
blocking dialog during any running operation. Use inline status panels and
non-blocking notifications. The Cancel button is always enabled during operations
and triggers immediate graceful cancellation with automatic rollback (see Section
0.5.2 for the cancellation and rollback architecture).

**Undo/Redo:** All configuration changes made through the GUI (outside of the install
wizard) are tracked in `ConfigHistory` (see Section 0.7.4) and must be undoable via
Ctrl+Z / Ctrl+Y or Edit menu items. The install wizard itself is not undoable via
Ctrl+Z — it uses the Cancel+rollback mechanism instead.

**Snapshot UI (anticipated scope — do not implement until Phase 2 is planned):**
A "Snapshots" panel in the main window lists all saved snapshots with labels and
timestamps. "Create Snapshot" button (requires a label). "Restore" button restores
config only (certs + PKCS11, no packages or services). Restore runs in a worker
thread with a progress panel and Cancel button.

### Phase 2 Dependencies

These packages are **not** installed by the Phase 1 Bash scripts. They will be
added to the Phase 2 installer and documented in `gui/requirements.txt`.

| Package (Arch/CachyOS) | Purpose |
|---|---|
| `python-pyqt6` | PyQt6 — Qt6 Python bindings for all GUI components |
| `libayatana-appindicator` | Modern successor to `libappindicator`; provides system tray indicator support with D-Bus status notification (SNI protocol) |
| `python-gobject` | GObject Introspection runtime — required for Python bindings to `libayatana-appindicator` via `gi.repository` |
| `gobject-introspection` | GObject Introspection typelib support |

> **Note on libappindicator vs libayatana-appindicator:** The original
> `libappindicator-gtk3` has been superseded on Arch/CachyOS by
> `libayatana-appindicator`. CachyOS 2025 updates transitioned away from the
> legacy GTK3 variant. The Phase 2 implementation plan will confirm the final
> library choice (`QSystemTrayIcon` via Qt6, or `gi.repository.AyatanaAppIndicator3`)
> based on desktop environment compatibility requirements at that time.

---

### 8.1 Installation Dialog (Placeholder)

> 📋 **Requirements not yet provided.** This subsection will be replaced with a full
> implementation plan when the user supplies requirements for the installation dialog.

**Anticipated scope (do not implement yet):**
- PyQt6 wizard-style (`QWizard`) installation dialog
- Calls `orchestrator.runner.stream_bash(bash_dir / 'install.sh')` in a `QThread` worker and consumes the yielded line stream to drive the progress view; no new subprocess logic needed
- Displays phase-by-phase progress (packages, service, certs, PKCS11, verification)
- Handles errors from the Bash script and presents them as inline error panels (non-modal)
- Provides "Install" / "Uninstall" / "Cancel" flow; Cancel is always enabled and triggers automatic rollback via `run_uninstall()` on the partial state

---

### 8.2 Application Loading Splash Screen (Placeholder)

> 📋 **Requirements not yet provided.** This subsection will be replaced with a full
> implementation plan when the user supplies requirements for the splash screen.

**Anticipated scope (do not implement yet):**
- `QSplashScreen`-based loading screen displayed on application startup
- Shows application logo/branding while the main window and AppIndicator initialize
- Displays a brief status message (e.g., "Initializing smart card services…")
- Dismisses automatically when the main window or tray icon is ready

---

### 8.3 App Indicator and Context Menu (Placeholder)

> 📋 **Requirements not yet provided.** This subsection will be replaced with a full
> implementation plan when the user supplies requirements for the app indicator.

**Anticipated scope (do not implement yet):**
- Resident system tray icon using `libayatana-appindicator` (or `QSystemTrayIcon`
  per Phase 2 design decision) that remains visible after the main window is closed
- Context menu items (minimum expected set):
  - Open main window
  - CAC/reader status summary (read-only label)
  - Run CAC Setup (launches installer dialog)
  - Run CAC Uninstall (with confirmation)
  - Quit application
- Icon reflects current smart card/reader state (e.g., card present, no card, error)
- Desktop environment compatibility: GNOME, KDE Plasma, Xfce, and other major DEs
  supported by CachyOS

---

### 8.4 Main GUI — ActivClient-Style Viewer (Placeholder)

> 📋 **Requirements not yet provided.** This subsection will be replaced with a full
> implementation plan when the user supplies ActivClient-style GUI requirements.

**Anticipated scope (do not implement yet):**
- Main application window modeled after ActivClient (HID Global's DoD smart card
  management application for Windows/macOS)
- Typical ActivClient display panels include:
  - Smart card reader status and connected reader name
  - Card identity information (name on card, Employee ID / EDIPI)
  - Certificate list (Authentication, Encryption, Identity) with validity dates
  - Certificate detail viewer (subject, issuer, serial number, expiry, key usage)
  - PIN management (change PIN, unlock card)
  - Card diagnostics and reader enumeration
- Data sourced from OpenSC tools (`opensc-tool`, `pkcs15-tool`) and/or
  PKCS11 library calls via `python-pkcs11` or equivalent
- Detailed requirements and exact panel layout will be provided by the user
  before this subsection is planned

---

## 9. Phase 3: GitHub Actions CI/CD

Phase 3 configures GitHub Actions to run automatically on every push to `main` and on all pull requests targeting `main`. Two workflow files are planned:

- `.github/workflows/ci.yml` — continuous integration: linting, syntax checks, BATS unit tests
- `.github/workflows/release.yml` — release automation: creates GitHub Releases from version tags

Phase 3 is **not implemented until Phase 1 is functionally complete and tested locally**. However, CI readiness is a first-class concern throughout Phase 1 development — each implementation step notes what it must expose to be testable in CI.

### 9.1 Platform Constraint: No Arch Linux Runner

GitHub Actions provides no official Arch Linux runner. All jobs run on `ubuntu-latest` unless a self-hosted Arch runner is configured.

**Consequence — CI cannot** (on `ubuntu-latest` without a container):
- Install or validate Arch/CachyOS-specific packages (`yay`, `paru`, `opensc`, `pcsc-tools`)
- Test `pcscd` socket activation
- Validate AUR helper detection
- Run integration tests that require real system state

> **Note:** Section 12.1 adds a `bats-arch` job using `container: archlinux:latest` that addresses several of the above limitations. With the Arch container, CI can install real Arch packages and test BATS files against actual Arch binary paths — without a self-hosted runner. See Section 12.1 for the updated capability summary and YAML.

**CI can** (on `ubuntu-latest` with mocks — complemented by `bats-arch` with real packages):
- Lint all `.sh` files with `shellcheck` (runs on any platform)
- Validate Python syntax and style
- Run BATS unit tests that mock all system commands (no real packages, no sudo)
- Check `bash -n` syntax on all Bash files

**Self-hosted runner path (optional, future):** A self-hosted Arch or CachyOS runner could enable full integration testing. This is out of scope for the initial Phase 3 but is architecturally accommodated by keeping integration tests in a separate BATS file (`tests/integration/`) that CI skips via a `[[ -z "${CI_INTEGRATION:-}" ]]` guard. Self-hosted runner setup would be documented in `CONTRIBUTING.md` when pursued.

### 9.2 CI Readiness Contract

Each Phase 1 implementation step must satisfy the following before Phase 3 is activated:

| Requirement | Verification Command |
|---|---|
| All `.sh` files pass `shellcheck -x` | `shellcheck -x lib/*.sh bash/*.sh` |
| All `.sh` files pass `bash -n` | `bash -n lib/*.sh bash/*.sh` |
| All Python files pass `ruff check` | `ruff check orchestrator/ distros/ *.py` |
| BATS unit tests exist and pass for every `lib/*.sh` function | `bats tests/*.bats` |
| No BATS unit test calls a real system binary without a mock | Review `tests/mocks/` |
| No test writes outside `/tmp/` or `BATS_TMPDIR` | Audit test output paths |

**Mocking strategy for BATS:** Each BATS unit test file prepends `tests/mocks/` to `PATH` before sourcing any `lib/` file. The mock directory contains executable shell stubs that override real system binaries (`pacman`, `systemctl`, `modutil`, `certutil`, `sha256sum`, `wget`) with controlled stubs. This keeps lib functions testable without root, hardware, or Arch-specific packages.

**Mock directory layout** (consistent with Section 2 project structure):
```
tests/
  mocks/
    pacman        # stub: records args, returns 0
    systemctl     # stub: records args, returns configurable exit code
    modutil       # stub
    certutil      # stub
    sha256sum     # stub: returns preconfigured checksum output
    wget          # stub: copies fixture file to expected output path
  test_log.bats
  test_detect.bats
  test_aur.bats
  test_packages.bats
  test_service.bats
  test_opensc_conf.bats
  test_certs.bats
  test_browser.bats
  test_import.bats
  test_pkcs11.bats
  test_verify.bats
  integration/    # skipped in hosted CI; requires real Arch system
    test_full_install.bats
```

The `CI_INTEGRATION` environment variable gates integration tests: the `integration/` subdirectory guard `[[ -z "${CI_INTEGRATION:-}" ]]` is always unset on hosted GitHub runners, so integration tests are skipped automatically without any workflow-level configuration. A self-hosted Arch runner sets `CI_INTEGRATION=1` in its job environment to enable them.

### 9.3 Workflow: `ci.yml`

**Trigger:** `push` to any branch; `pull_request` targeting `main`

**Jobs:**

1. **`bash-syntax`** — runs `bash -n` on all `lib/*.sh` and `bash/*.sh` as a fast pre-check
2. **`shellcheck`** — runs `shellcheck -x` on all `lib/*.sh` and `bash/*.sh`
3. **`python-lint`** — installs `ruff`, runs against `orchestrator/`, `distros/`, and all `*.py` entry points
4. **`python-tests`** — runs Python unit tests under `tests/test_orchestrator/` via stdlib `unittest`
5. **`bats-unit`** — installs `bats-core` from source (Ubuntu apt package may be outdated), runs `bats tests/*.bats`

**Job ordering:** `bash-syntax` and `shellcheck` run in parallel as independent fast checks. `bats-unit` depends on both `bash-syntax` and `shellcheck` so that syntax or linting failures gate test execution — running tests on malformed files wastes runner time and produces misleading output. `python-lint` and `python-tests` run independently of the Bash jobs.

**Working directory note:** All jobs use `working-directory: cachy_cac` (relative to the repository root) because scripts live in `cachy_cac/lib/` and `cachy_cac/bash/`, not at the repository root.

**Planned file:** `.github/workflows/ci.yml`

```yaml
# Skeleton — not yet implemented; complete during Phase 3
name: CI

on:
  workflow_call:   # allows release.yml to call this workflow and block on its result
  push:
    branches: ["*"]
  pull_request:
    branches: [main]

jobs:
  bash-syntax:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: cachy_cac
    steps:
      - uses: actions/checkout@v4
      - name: Syntax check
        run: bash -n lib/*.sh bash/*.sh

  shellcheck:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: cachy_cac
    steps:
      - uses: actions/checkout@v4
      - name: ShellCheck
        run: |
          sudo apt-get install -y shellcheck
          shellcheck -x lib/*.sh bash/*.sh

  python-lint:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: cachy_cac
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - name: Lint
        run: |
          pip install ruff
          ruff check orchestrator/ distros/ *.py

  python-tests:
    # Python version matrix — expanded in Section 12.12; apply matrix before activating
    strategy:
      matrix:
        python-version: ["3.10", "3.11", "3.12"]
      fail-fast: false
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: cachy_cac
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      - name: Unit tests
        run: python3 -m unittest discover -s tests/test_orchestrator -v

  # bats-arch job (Arch container) is defined in Section 12.1 — add before activating
  bats-unit:
    needs: [bash-syntax, shellcheck]
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: cachy_cac
    steps:
      - uses: actions/checkout@v4
      - name: Install bats-core
        run: |
          git clone https://github.com/bats-core/bats-core.git /tmp/bats
          sudo /tmp/bats/install.sh /usr/local
      - name: Run unit tests
        run: bats tests/*.bats
```

### 9.4 Workflow: `release.yml`

**Trigger:** `push` of a tag matching `v*.*.*` (e.g., `v1.0.0`) on the `main` branch

**Purpose:** Automatically create a GitHub Release when a version tag is pushed. The release attaches a source archive and a SHA-256 checksum file.

**Jobs:**

1. **`ci`** — re-runs `ci.yml` as a called workflow (`uses: ./.github/workflows/ci.yml`) to verify all checks pass on the release commit before anything is published. Because `ci.yml` declares `on: workflow_call:`, `release.yml` can call it synchronously and block the release job until it succeeds. This is preferable to `workflow_run` (which only checks that CI ran at some point, not that it passed on the exact release SHA).

2. **`create-release`** — depends on the `ci` job; builds the source archive, computes `SHA256SUMS`, and calls `softprops/action-gh-release` to publish the GitHub Release. Requires `permissions: contents: write` to create releases and upload assets.

**Version tagging convention:** `vMAJOR.MINOR.PATCH`
- MAJOR: breaking changes (communication protocol change, state schema change, removed browser or arch support)
- MINOR: new feature additions (new browser support, new distro driver, Phase 2 GUI)
- PATCH: bug fixes, certificate URL/checksum updates, documentation corrections

**Changelog:** Release notes are written manually in the GitHub Release body. A `CHANGELOG.md` file at the repository root maintains the same content in a persistent, browsable form. There is no automated changelog generation tool — the curator writes a short, human-readable summary of changes for each release. The `CHANGELOG.md` entry for a release is merged as part of the release commit, before the tag is pushed.

**Branch protection requirement:** `release.yml` must only fire from `main`. Branch protection rules on `main` require all `ci.yml` checks to pass before merge. This is configured in GitHub repository settings, not in the workflow file. Document the required branch protection settings in `CONTRIBUTING.md` (a Phase 3 deliverable, added to `cachy_cac/` when Phase 3 is implemented).

**Planned file:** `.github/workflows/release.yml`

```yaml
# Skeleton — not yet implemented; complete during Phase 3
name: Release

on:
  push:
    tags:
      - "v*.*.*"

jobs:
  ci:
    uses: ./.github/workflows/ci.yml   # calls ci.yml synchronously; blocks if any check fails

  create-release:
    needs: ci
    runs-on: ubuntu-latest
    permissions:
      contents: write    # required to create GitHub Releases and upload assets
    steps:
      - uses: actions/checkout@v4
      - name: Build archive
        run: |
          VERSION="${GITHUB_REF_NAME}"
          # .github/ is at the repository root, not inside cachy_cac/, so no
          # explicit exclude is needed for it — only cachy_cac/ is archived.
          tar --exclude='cachy_cac/tests' \
              --exclude='*/__pycache__' \
              --exclude='*.pyc' \
              -czf "cachy_cac-${VERSION}.tar.gz" cachy_cac/
          sha256sum "cachy_cac-${VERSION}.tar.gz" > SHA256SUMS
          # Extract the Unreleased section from CHANGELOG.md as the release body
          sed -n '/^## \[Unreleased\]/,/^## \[/p' CHANGELOG.md \
            | sed '1d;$d' > RELEASE_NOTES.md
          # Fail fast if the Unreleased section is empty — release notes are required
          [[ -s RELEASE_NOTES.md ]] || { echo "[ERROR] CHANGELOG.md [Unreleased] section is empty — populate it before releasing" >&2; exit 1; }
      - name: Publish release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            cachy_cac-*.tar.gz
            SHA256SUMS
          body_path: RELEASE_NOTES.md
```

### 9.5 CI Readiness Annotations in Phase 1

During Phase 1 implementation, each Bash library file (`lib/*.sh`) includes a comment block near the top noting its CI testability status. This is not enforced by CI but provides a human-readable checklist for Phase 3 setup:

```bash
# CI-TESTABLE: yes | partial | no
# MOCK-DEPS: <space-separated list of commands mocked in BATS tests>
# UNIT-TEST-FILE: tests/test_<name>.bats
# INTEGRATION-ONLY: <any functions that require a real Arch system to test>
```

A function is `partial` if some code paths can be unit-tested with mocks and others require a real system (e.g., `lib/service.sh` can mock `systemctl enable` but cannot verify socket activation without `pcscd`).

This annotation applies to Bash library files (`lib/*.sh`) only. Python modules in `orchestrator/` and `distros/` are assumed fully unit-testable via mocking (`unittest.mock`) without system dependencies; any exceptions are noted in the relevant test file's docstring.

---

## 10. Phase 4: Quarterly Release Cadence and Issue/PR Management

### 10.0 Overview

Phase 4 establishes the ongoing maintenance process for the project after Phase 1 (and optionally Phase 2) are publicly released. It defines:

- A **quarterly release cadence** for collecting and shipping corrections
- A **triage and intake process** for GitHub Issues and pull requests
- A **per-item analysis framework** that produces a written implementation plan for every issue or PR before work begins
- A **deep analysis protocol** for evaluating compatibility, scope, and necessity

Quarterly releases are **conditional** — a release is only cut if corrections, updates, or accepted changes have accumulated. If a quarter passes with no actionable items, no release is made.

### 10.1 Release Cadence

**Schedule:** Releases target the first week of each calendar quarter:
- Q1: first week of January
- Q2: first week of April
- Q3: first week of July
- Q4: first week of October

**Trigger conditions** — a quarterly release is cut if any of the following exist:
- Merged bug fixes since the last release
- Accepted certificate URL or checksum updates (DoD PKI certs change on an irregular schedule)
- Accepted pull requests from external contributors
- Dependency version updates requiring code changes

**No-release quarter:** If none of the above conditions are met, the quarterly checkpoint is recorded as a brief entry in `CHANGELOG.md` noting that no corrections were required for that quarter. Maintaining this record demonstrates that the project is actively monitored even when silent. Note: GitHub Discussions must be enabled in repository settings before it can be used for announcements; enable it as a Phase 4 repository setup step.

**Tag convention:** `vMAJOR.MINOR.PATCH` — patch increments for bug/cert fixes, minor for new features, major for breaking changes (see Section 9.4 for the full versioning policy).

**Release notes:** Each release must include a curated changelog in the GitHub Release body covering: fixed issues (by number), accepted PRs (by number and contributor), certificate/URL changes, and any known regressions or deferred items.

### 10.2 Issue Intake and Triage

When a new GitHub Issue is filed:

1. **Label assignment (target: within 7 days):**
   - Type: `bug` / `enhancement` / `question` / `documentation` / `security`
   - Scope: `phase-1-cli` / `phase-2-gui` / `phase-3-ci`
   - Platform: `arch` / `aarch64` / `cross-compat`
   - Status: `needs-triage` initially; replaced when evaluation is complete

2. **Reproducibility check:** For bug reports, confirm whether the issue is reproducible on a clean CachyOS install. Issues that cannot be reproduced after one follow-up cycle are labeled `cannot-reproduce` and closed with a clear explanation.

3. **Duplicate detection:** Search existing open and closed issues before assigning a milestone. Link to the canonical issue if a duplicate is filed; close the duplicate.

4. **Security issues:** Issues involving credential exposure, NSS database corruption, or pcscd privilege escalation are labeled `security` and handled outside the quarterly cycle — evaluated and patched immediately if confirmed. Security fixes are released as out-of-cycle patch releases.

5. **Stale policy:** Issues with no activity for 30 days after a `needs-info` label is applied are closed automatically with a comment directing the reporter to reopen with updated information. Automation is handled by the `actions/stale` GitHub Action (add a `.github/workflows/stale.yml` workflow as part of Phase 4 repository setup). This eliminates the need to manually monitor and close abandoned issues.

### 10.3 Pull Request Intake and Evaluation

When a pull request is opened, the following questions must be answered before any work is merged. Answers are recorded in the per-item implementation plan (Section 10.4).

#### 10.3.1 Necessity Evaluation

- Does this PR address a confirmed bug or accepted enhancement, or is it unsolicited?
- Could the problem be solved with a documentation or configuration fix instead of a code change?
- If the PR is unsolicited: does it align with the project's stated goals (CachyOS/Arch CAC setup)?
- Is the PR complete (tests included, CI passing, documentation updated) or does it require significant rework before it can be considered?

#### 10.3.2 Cross-Compatibility Analysis

| Dimension | Questions to Answer |
|---|---|
| Arch / CachyOS | Does the change rely on Arch-specific package names or paths? Is it safe for future Debian/Fedora support? |
| x86_64 vs aarch64 | Has the change been tested on both architectures? Does it hardcode any arch-specific paths? |
| Firefox vs Chromium | Does the change affect one browser's NSS database handling in a way that breaks the other? |
| Phase 2 GUI | Does a CLI change alter any contract that the Phase 2 GUI depends on (Section 0.2, Section 0.5)? |
| Desktop environment | For Phase 2 GUI changes: does the change work on GNOME, KDE Plasma, and Xfce? |

#### 10.3.3 Breaking Change Analysis

A change is **breaking** if it:
- Alters the `STATE:<key>=<value>` or `ACTION:<type>|...` communication protocol (Section 0.2)
- Changes the schema of `state.json` or `action_log.json` in a backwards-incompatible way
- Renames, removes, or changes the calling signature of a public function in `orchestrator/`
- Changes default install paths or file locations that an existing install has already written
- Removes support for a previously supported browser, architecture, or AUR helper

Breaking changes require a MAJOR version bump, explicit migration documentation, and must be called out in the release notes.

#### 10.3.4 Security Implications

Every PR touching the following areas is flagged for elevated review before merge:

| File / Area | Reason |
|---|---|
| `lib/certs.sh` | Certificate download and checksum validation — supply chain risk |
| `lib/import.sh` | NSS database writes — trust store integrity |
| `lib/pkcs11.sh` | PKCS11 module registration — authentication surface |
| `orchestrator/runner.py` | Subprocess construction — command injection risk |
| Any file constructing shell commands from external input | Injection risk |

Elevated review requires: an explicit test for the security-sensitive path, review of all subprocess argument construction for injection risk, and confirmation that no new privilege escalation surface is introduced without justification.

#### 10.3.5 CI Gate

No PR is merged unless all `ci.yml` checks pass. Once Phase 3 is active, this is enforced by branch protection rules. Before Phase 3 is active, a manual checklist is completed and recorded as a PR comment before merge:

- [ ] `shellcheck -x lib/*.sh bash/*.sh` passes locally
- [ ] `bash -n lib/*.sh bash/*.sh` passes locally
- [ ] `ruff check orchestrator/ distros/ *.py` passes locally
- [ ] `bats tests/*.bats` passes locally
- [ ] Install/Uninstall Symmetry Contract maintained (Section 0.4)

### 10.4 Per-Item Implementation Plan Template

Before any issue fix or accepted PR is merged, a written implementation plan is produced. The plan is recorded as a comment on the issue or PR. For larger changes, it may be a linked document in `docs/decisions/`.

```markdown
## Implementation Plan: <Issue/PR Title>

**Issue/PR:** #<number>
**Type:** Bug | Enhancement | Documentation | Security | Dependency Update
**Scope:** Phase 1 CLI | Phase 2 GUI | Phase 3 CI | Cross-Phase
**Target release:** vX.Y.Z (QN YYYY)

### 1. Problem Statement
<What is broken or missing? What is the user-visible impact?>

### 2. Necessity Evaluation
<Is this a code fix, a documentation fix, or a configuration update?
Is a PR required, or can this be addressed without a code change?>

### 3. Cross-Compatibility Assessment

| Dimension        | Impact              | Notes |
|------------------|---------------------|-------|
| Arch / CachyOS   | Yes / No / Unknown  |       |
| x86_64           | Yes / No / Unknown  |       |
| aarch64          | Yes / No / Unknown  |       |
| Firefox          | Yes / No / Unknown  |       |
| Chromium         | Yes / No / Unknown  |       |
| Phase 2 GUI      | Yes / No / Unknown  |       |

### 4. Breaking Change Assessment
<Is this a breaking change? If yes, what is the migration path
and what version bump does it require?>

### 5. Security Review
<Does this touch security-sensitive code (see Section 10.3.4)?
What is the risk surface? Has injection risk been evaluated?>

### 6. Implementation Steps
1. <Step>
2. <Step>

### 7. Test Coverage
<What new or modified BATS tests are required?
What CI checks will verify this change?>

### 8. Acceptance Criteria
<Specific, verifiable conditions that indicate the fix is correct and complete.>
```

### 10.5 Deep Analysis: Approach to Incorporating External Contributions

This section establishes the analytical framework for evaluating whether and how to incorporate changes from the community — GitHub Issues, pull requests, and user-reported defects — into the project's formal quarterly release cycle.

#### 10.5.1 Guiding Principles

1. **Security first.** This project configures DoD PKI trust stores and PKCS11 modules on users' systems. Any contribution that weakens certificate validation, introduces command injection surface, or silently modifies NSS databases is rejected regardless of other merit.

2. **Arch-native, not generic.** Contributions that generalize the tool toward Debian/Ubuntu compatibility without a concrete plan for the distro abstraction layer (Section 0.3) create technical debt. Accept architecture-agnostic improvements; hold Debian support contributions until a proper driver is designed and planned.

3. **Minimal surface.** The tool does a narrow, well-defined job. Enhancements that expand scope beyond CAC/smart card setup for CachyOS — browser extensions, VPN configuration, unrelated package installation — are out of scope and declined with explanation.

4. **Reversibility.** Every accepted change must maintain the Install/Uninstall Symmetry Contract (Section 0.4). A contribution that installs or modifies something with no uninstall counterpart is not accepted until the uninstall path is included.

5. **CI gate is non-negotiable.** Once Phase 3 is active, no exception is made for bypassing CI checks. The `--no-verify` equivalent does not exist in this project's merge process.

#### 10.5.2 Triage Decision Tree

```
New Issue or PR filed
        │
        ▼
Is it a security issue?
  ├─ Yes → Handle immediately outside quarterly cycle (Section 10.2, step 4)
  └─ No
        │
        ▼
Is it reproducible / sufficiently described?
  ├─ No  → Request information; label `needs-info`
  │        Close if no response within 30 days
  └─ Yes
        │
        ▼
Is it in scope (CachyOS CAC setup)?
  ├─ No  → Close with explanation; label `out-of-scope`
  └─ Yes
        │
        ▼
Is it a duplicate?
  ├─ Yes → Link to canonical issue; close duplicate
  └─ No
        │
        ▼
Does it require a code change?
  ├─ No  → Documentation or config fix; assign to next quarterly release
  └─ Yes
        │
        ▼
Does it alter the communication protocol, state schema,
or public orchestrator API? (Section 10.3.3)
  ├─ Yes → Flag as breaking; plan MAJOR version bump
  └─ No
        │
        ▼
Does it affect cross-platform compatibility? (Section 10.3.2)
  ├─ Yes → Require cross-platform test evidence before accepting
  └─ No
        │
        ▼
Assign to quarterly milestone
        │
        ▼
Produce per-item plan (Section 10.4)
        │
        ▼
Implement → CI must pass → Code review → Merge → Tag → Release
```

#### 10.5.3 Certificate and URL Maintenance

DoD PKI root and intermediate certificate bundles change on an irregular schedule. Certificate URL updates are a recurring maintenance task distinct from feature development:

- `lib/certs.sh` hardcodes the DoD cert bundle download URL and expected SHA-256 checksum. When the bundle changes, both must be updated atomically.
- Certificate updates are treated as **patch releases** and do not require a full quarterly cycle — they may be released immediately if the existing URL returns a 404 or the downloaded file no longer matches the stored checksum.
- The abbreviated per-item plan for a cert update: confirm the new URL, validate the new checksum against a known-good download, test the full install flow on a clean system, update `lib/certs.sh`, tag, and release.
- Monitor the DoD PKI distribution site and the upstream `linux_cac` project's issue tracker for advance notice of certificate changes.

#### 10.5.4 Contributor Communication Standards

- Every issue receives a response within 7 days, even if only to acknowledge and apply labels.
- Every pull request receives a first review within 14 days.
- Declined contributions receive a clear, non-dismissive explanation referencing the relevant guiding principle from Section 10.5.1.
- Accepted contributions from external contributors are credited in release notes by GitHub handle.
- All discussion is conducted in the issue or PR thread, not in side channels, to maintain a public record.

#### 10.5.5 Backlog and Milestone Management

- All accepted issues and PRs targeting the next quarterly release are added to a GitHub Milestone named for the target release (e.g., `v1.1.0 - Q2 2026`).
- Items accepted but deferred beyond the next quarter are placed in a `Backlog` milestone with a comment explaining the deferral rationale (capacity, dependency on another change, waiting for upstream, etc.).
- At the start of each quarterly planning cycle, the backlog is reviewed: items that have become urgent (security-adjacent, blocking users at scale, or dependency-unblocked) are promoted to the current milestone.
- The milestone for the current quarter is closed and a new one is opened when the quarterly release tag is pushed.

---

## 11. Phase 5: Help Guide

### 11.0 Overview

Phase 5 implements the Help system for the Phase 2 GUI application. It provides a fully searchable, navigable Help dialog accessible from the main window's Help menu and via F1.

**Phase dependency:** Phase 5 requires Phase 2 (PyQt6 GUI) to be implemented. The `HelpDialog` class, search engine, and GUI integration cannot be built until the Phase 2 main window and menu bar exist. However, all help content files (`gui/help/content/*.md`) and `index.json` can be authored in parallel with Phase 2 development — they are plain-text files with no code dependencies.

**Not a placeholder.** Unlike Sections 8.1–8.4, this section is a complete implementation plan. Do not begin implementation until Phase 2 is functional, but requirements are fully specified here.

---

### 11.1 Architecture

**Entry points:**
- `Help` menu → `Open Help…` item in the main window's `QMenuBar`
- `F1` keyboard shortcut bound as a `QShortcut` in `QMainWindow`
- "Help" button in the Phase 2 installation wizard footer (optional, Phase 2 decision)

**Widget:** `HelpDialog(QDialog)` defined in `gui/help/help_dialog.py`

**Content format:** Markdown source files in `gui/help/content/`. Converted to HTML at dialog launch using the `python-markdown` package (`python-markdown` on Arch/CachyOS; `Markdown` on pip).

**Renderer:** `QTextBrowser` — renders a rich subset of HTML natively with no additional Qt module dependencies. Selected over `QWebEngineView` because `QWebEngineView` requires `qt6-webengine` (~300 MB) and spawns a Chromium subprocess. `QTextBrowser` handles styled HTML, inline images, tables, and internal anchor links — sufficient for static help content with no additional Phase 5 dependencies.

**Help content pipeline:**
```
gui/help/content/*.md
        │
        ▼  (at HelpDialog.__init__(), on main thread — <100ms total)
markdown.markdown() per file  (tables + fenced_code extensions)
        │
        ▼
dict[topic_id → HTML string]  (held in memory for dialog lifetime)
        │
        ├──► HelpSearchIndex.build()
        │      strips HTML tags → builds inverted word index
        │      word → frozenset[topic_id]
        │
        └──► QTreeWidget population from index.json
                    │
                    ▼  (on topic selection)
             optional inject_highlights() → QTextBrowser.setHtml()
```

**Threading:** All operations in `HelpDialog.__init__()` are local file reads and string processing. No network I/O, no subprocess. Completes in under 100ms for the anticipated content volume. No worker thread is required for the help system.

---

### 11.2 UI Layout

```
┌──────────────────────────────────────────────────────────────────┐
│  Help — CachyOS CAC Setup                                   [×]  │
├──────────────────────┬───────────────────────────────────────────┤
│ [🔍 Search help…] [×]│                                           │
│──────────────────────│   (Content Pane — QTextBrowser)           │
│ Topics               │                                           │
│  ▼ Getting Started   │   ## Getting Started                      │
│    ▷ What Is a CAC?  │                                           │
│    ▷ Requirements    │   Welcome to CachyOS CAC Setup…           │
│    ▷ What App Does   │                                           │
│  ▼ Installation      │                                           │
│    ▷ Before You Begin│                                           │
│    ▷ Running Installer                                           │
│    ▷ What Changes    │                                           │
│    ▷ Verifying       │                                           │
│  ▶ Uninstallation    │                                           │
│  ▶ Smart Card Reader │                                           │
│  ▶ Browser Setup     │                                           │
│  ▶ Certificates      │                                           │
│  ▶ Troubleshooting   │                                           │
│  ▶ Log Files         │                                           │
│  ▶ Snapshots         │                                           │
│  ▶ Keyboard Shortcuts│                                           │
│  ▶ About             │                                           │
│                      ├───────────────────────────────────────────┤
│                      │ [◀ Previous]              [Next ▶]        │
└──────────────────────┴───────────────────────────────────────────┘
```

**Left panel:** `QTreeWidget` (fixed width ~220px, minimum 160px). Top-level items are sections; child items are subsections. Selecting any item loads its page into the content pane and scrolls to the subsection anchor if a child item is selected. Initial state: all top-level items expanded.

**Search bar:** `QLineEdit` at the top of the left panel, with a clear button (×) that appears when text is present. Real-time search fires on `textChanged` with a 200ms debounce (`QTimer.singleShot`). Behavior while a query is active:
- `QTreeWidget` filters to show only items whose page contains all query words; parents remain visible if any child matches; unmatched items are hidden (not removed)
- Content pane: the current topic's HTML has `<mark>` tags injected around every occurrence of each query word before `QTextBrowser.setHtml()` is called
- `mark { background-color: #ffff00; color: #000000; }` is prepended to the document `<head>`
- Pressing × in the search bar clears the query, restores the full tree, and reloads the current topic without highlight injection

**Content pane:** `QTextBrowser` fills the right panel. `setOpenLinks(False)` is set. The `anchorClicked(QUrl)` signal routes:
- `http://` / `https://` → `QDesktopServices.openUrl()` (opens system browser)
- `help://<topic_id>` internal links → `load_topic(topic_id)` (navigate within the dialog)

**Navigation buttons:** "◀ Previous" and "Next ▶" at the bottom-right of the dialog cycle through all leaf topics in `index.json` reading order. `QPushButton`, disabled at the first and last topic respectively. Keyboard-navigable via Tab order.

**Dialog geometry:** Default 900×600px; resizable; minimum 600×400px. `QSplitter` between the left panel and content pane. Geometry, splitter position, and the last-viewed topic ID are saved to `QSettings("CachyOS-CAC", "HelpDialog")` and restored on next open.

---

### 11.3 File Layout

```
gui/
  help/
    __init__.py
    help_dialog.py          # HelpDialog(QDialog) — main widget class
    search.py               # HelpSearchIndex — inverted word index and search
    renderer.py             # markdown_to_html(), inject_highlights(), strip_html()
    index.json              # TOC: ordered array of topic objects
    content/
      getting_started.md
      installation.md
      uninstallation.md
      smart_card_reader.md
      browser_setup.md
      certificate_management.md
      troubleshooting.md
      log_files.md
      snapshots.md
      keyboard_shortcuts.md
      about.md
```

**`index.json` schema:**

```json
[
  {
    "id": "getting_started",
    "title": "Getting Started",
    "file": "getting_started.md",
    "children": [
      { "id": "what_is_cac",   "title": "What Is a CAC?",       "anchor": "what-is-a-cac" },
      { "id": "requirements",  "title": "System Requirements",   "anchor": "system-requirements" },
      { "id": "what_app_does", "title": "What This App Does",    "anchor": "what-this-app-does" }
    ]
  },
  {
    "id": "installation",
    "title": "Installation",
    "file": "installation.md",
    "children": [
      { "id": "before_begin",  "title": "Before You Begin",               "anchor": "before-you-begin" },
      { "id": "running",       "title": "Running the Installer",          "anchor": "running-the-installer" },
      { "id": "what_changes",  "title": "What the Installer Changes",     "anchor": "what-the-installer-changes" },
      { "id": "verifying",     "title": "Verifying the Installation",     "anchor": "verifying-the-installation" }
    ]
  }
]
```

`"anchor"` values are Markdown heading slugs (all lowercase; spaces and special characters replaced with hyphens). `QTextBrowser.scrollToAnchor()` is used to navigate to a specific heading when a child item is selected. Top-level items scroll to the top of their page (no anchor).

---

### 11.4 Class and Module Specifications

#### `gui/help/help_dialog.py` — `HelpDialog(QDialog)`

Public interface:

```python
class HelpDialog(QDialog):
    def __init__(self, parent=None): ...
        # 1. Load and parse index.json
        # 2. Call renderer.markdown_to_html() for each content file
        # 3. Build HelpSearchIndex from stripped-text versions of each page
        # 4. Populate QTreeWidget from index
        # 5. Build QTextBrowser, QLineEdit search bar, navigation buttons
        # 6. Wire all signals
        # 7. Restore geometry from QSettings
        # 8. Load last-viewed topic or "getting_started" if no saved state

    def load_topic(self, topic_id: str, anchor: str | None = None) -> None: ...
        # Sets content pane to topic's HTML (with highlights if search active)
        # Scrolls to anchor if provided

    def _filter_topics(self, query: str) -> None: ...
        # Debounced: called 200ms after textChanged
        # Hides/shows QTreeWidget items; reinjects highlights in current page

    def _clear_filter(self) -> None: ...
    def _navigate_prev(self) -> None: ...
    def _navigate_next(self) -> None: ...
    def _handle_link(self, url: QUrl) -> None: ...
    def _save_state(self) -> None: ...  # called on closeEvent
    def _restore_state(self) -> None: ...
```

#### `gui/help/search.py` — `HelpSearchIndex`

```python
class HelpSearchIndex:
    def __init__(self, pages: dict[str, str]) -> None:
        """
        pages: {topic_id: plain_text_content}
        Builds inverted index: normalized_word → frozenset[topic_id]
        Word normalization: lowercase, strip leading/trailing punctuation.
        """

    def search(self, query: str) -> list[str]:
        """
        Returns list of topic_ids where ALL query words appear.
        Case-insensitive. Results ordered by descending match density
        (total query word occurrences in page text).
        Empty query returns [].
        """
```

#### `gui/help/renderer.py` — utilities

```python
BASE_CSS = """
body { font-family: sans-serif; font-size: 14px; line-height: 1.6;
       margin: 16px 20px; color: #1a1a1a; }
h1 { font-size: 1.4em; border-bottom: 1px solid #ccc; padding-bottom: 4px; }
h2 { font-size: 1.15em; }
code { background: #f4f4f4; padding: 1px 4px; border-radius: 3px;
       font-family: monospace; }
pre  { background: #f4f4f4; padding: 10px; border-radius: 4px;
       overflow-x: auto; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #ddd; padding: 6px 10px; text-align: left; }
th { background: #f0f0f0; }
mark { background-color: #ffff00; color: #000000; }
"""

def markdown_to_html(md_text: str) -> str:
    """
    Converts Markdown to a full HTML document.
    Uses python-markdown with 'tables' and 'fenced_code' extensions.
    Injects BASE_CSS into <head>.
    """

def inject_highlights(html: str, query: str) -> str:
    """
    Wraps each query word in <mark> tags throughout the HTML body.
    Case-insensitive. Does not modify text inside HTML tag attributes.
    """

def strip_html(html: str) -> str:
    """
    Returns plain text from HTML string using html.parser.
    Handles common HTML entities (&amp;, &lt;, &gt;, &nbsp;, etc.).
    Used for building the search index.
    """
```

---

### 11.5 Help Content Outline

Each subsection below maps to one Markdown file. Content must be technically accurate and written for a non-expert user. All shell commands, file paths, and package names must be verified against the Phase 1 implementation before final authoring. Topics marked *(from KNOWN_ISSUES.md)* should pull directly from the documented known issues at the time of writing.

#### `getting_started.md`

**What Is a Common Access Card (CAC)?**
Plain-language explanation: the CAC is a DoD-issued smart card containing digital certificates and a PIN-protected private key. Browsers must be configured to communicate with the card reader and to trust the DoD certificate chain to authenticate to DoD websites and services.

**What This App Does**
Step-by-step plain-language walkthrough of the four core actions: (1) installs smart card daemon (`pcscd`) and OpenSC library, (2) enables and starts the card reader service, (3) downloads and imports DoD root and intermediate CA certificates into browser trust stores, (4) registers the OpenSC PKCS11 module so browsers can communicate with the card.

**System Requirements**
- CachyOS (x86_64 or aarch64)
- Supported browsers: Firefox, Chromium, Microsoft Edge (AUR), Brave (AUR)
- Hardware: any PC/SC-compliant USB smart card reader
- Sudo / root access required for setup and uninstall
- Internet connection required for the certificate download phase

#### `installation.md`

**Before You Begin**
- Close all web browsers completely
- Insert the USB smart card reader (but not the CAC card yet)
- Ensure internet connectivity
- Ensure sudo access is available

**Running the Installer**
Two methods: via app indicator context menu ("Run CAC Setup"), or CLI (`sudo python3 cac_setup.py`). Phase-by-phase progress description. What each green checkmark means in the GUI. What to do if a phase fails (the installer rolls back automatically; the log file records the failure location).

**What the Installer Changes**
Comprehensive table: every system modification made and its corresponding uninstall action. Packages installed (with per-package uninstall behavior). Service enabled (conditionally reversed on uninstall). Certificates imported (all removed on uninstall). PKCS11 module registered in each NSS database (all unregistered on uninstall).

**Verifying the Installation**
Using the GUI verification result. CLI equivalent: `bash bash/install.sh --phase=verify`. Inserting the CAC and expected behavior (PIN prompt when navigating to `https://my.af.mil` or similar CAC-protected site).

#### `uninstallation.md`

**Running the Uninstaller**
Via app: Help menu → Uninstall, or system tray → "Run CAC Uninstall" (with confirmation). Via CLI: `sudo python3 cac_uninstall.py`.

**What Is Removed**
- Packages: removed only if they were not present before setup ran; `pcsclite` is an example of a package that may be left installed if it was already present
- Service: `pcscd.socket` disabled and stopped only if it was not active before setup
- Certificates: all imported DoD CA certificates removed from every NSS database that was modified during setup
- PKCS11 module: unregistered from all NSS databases modified during setup

**Idempotency**
The uninstaller checks the action log and skips already-reversed actions. It is safe to run multiple times. The installer is safe to run immediately after uninstall.

#### `smart_card_reader.md`

**Supported Readers**
Any PC/SC-compliant USB reader. Reference to DoD-approved reader list (link). Common models: HID Omnikey 3021, SCR3310, Identiv uTrust 3700F.

**Detecting the Reader**
CLI: `opensc-tool --list-readers`. Expected output with reader present vs. absent. What the system tray icon shows when a reader is detected.

**Troubleshooting Reader Detection**
- `pcscd.socket` not active: `systemctl status pcscd.socket`; start with `systemctl start pcscd.socket`
- Reader not detected after replug: check `dmesg | tail -20` for USB events
- USB permission issue (reader works as root, not as user): check udev rules (out of scope for this application — link to Arch Wiki article on udev)

#### `browser_setup.md`

**How PKCS11 Works in Browsers**
Plain-language: the browser consults its NSS security module database (`pkcs11.txt`) on startup; if `opensc-pkcs11.so` is registered there, the browser can ask it for available smart card certificates when a site requests client authentication.

**Firefox**
- Registration path: `~/.config/mozilla/firefox/<profile>/pkcs11.txt`
- Verification: Firefox → Preferences → Privacy & Security → Security Devices → confirm "CAC Module" (or "OpenSC…") appears
- CachyOS-specific note: `pkcs11-register` does not detect Firefox profiles on CachyOS (profiles are in `~/.config/mozilla/firefox/`, not `~/.mozilla/firefox/`); this application uses `modutil` directly to avoid that failure

**Chromium and Chrome**
- Shared database: `~/.pki/nssdb`
- CLI verification: `modutil -dbdir sql:~/.pki/nssdb -list`
- GUI verification: `chrome://settings` → Security → Manage certificates (version-dependent)

**Microsoft Edge and Brave**
Use the same `~/.pki/nssdb` as Chromium. No separate configuration required.

**Adding a New Browser After Setup**
Re-running the installer is safe and idempotent. Already-registered databases are skipped; newly discovered databases are registered.

#### `certificate_management.md`

**What Certificates Are Imported**
DoD Root CA 2 through 6 and their associated intermediate CAs. Plain-language explanation: browsers do not ship DoD CA certificates by default; without them, DoD websites show privacy warnings even when presenting a valid CAC. Trust flags: `TC` — trusted as a CA for server authentication (`T`) and as a certificate authority (`C`).

**Viewing Certificates**
- Firefox: Preferences → Privacy & Security → View Certificates → Authorities → filter "DoD" or "Department of Defense"
- Chromium: `chrome://settings` → Security → Manage certificates → Authorities
- CLI: `certutil -L -d sql:~/.pki/nssdb | grep -i dod`

**When Certificates Need Updating**
DoD PKI issues new root certificates periodically. If CAC-protected sites show certificate errors after the CAC previously worked, the DoD bundle may have been updated. Re-running the installer downloads the current bundle and imports any new certificates (idempotent — already-present certificates are skipped).

**Using Snapshots**
Cross-reference to Snapshots section for save-and-restore of certificate configuration.

#### `troubleshooting.md`

Each issue: **Symptom** → **Likely Cause** → **Resolution steps**. Content drawn from `KNOWN_ISSUES.md` at Phase 5 authoring time:

1. CAC not detected in browser after setup — PKCS11 module not registered; browser not restarted after setup
2. Certificate selection dialog does not appear — browser was open during setup; NSS database not modified; re-run with browser closed
3. "No readers found" from `opensc-tool` — `pcscd.socket` not running; reader not plugged in
4. PIN dialog says "card not inserted" or "reader unavailable" — `pcscd.socket` stopped; unplug and replug reader
5. Setup fails during Package Installation — network issue; AUR helper not found; run `pacman -Syu` first
6. Setup fails during Certificate Download — DoD cert bundle URL changed (checksum mismatch); check log for URL; installer will report the mismatch explicitly
7. Setup fails during PKCS11 Registration — NSS database locked by open browser; close all browser windows; re-run
8. Setup completes but all verification checks fail — system clock significantly wrong (affects certificate validity checks)
9. Setup was working but stopped after a system update — OpenSC package updated and library path changed; re-run the installer
10. aarch64-specific issues — document any issues found during Phase 1 aarch64 testing
11. How to collect diagnostic information — log file path, `opensc-tool --list-readers`, `modutil -dbdir sql:~/.pki/nssdb -list`, `pacman -Q opensc pcsclite nss`

#### `log_files.md`

- Log location: `/var/log/cachy_cac_YYYYMMDD_HHMMSS.log` (one per run)
- Access from GUI: Log Viewer panel in the main window (Phase 2 feature)
- Access from CLI: `cat "$(ls -t /var/log/cachy_cac_*.log | head -1)"`; filter errors: `grep '\[ERROR\]\|\[WARN\]' <logfile>`
- Log tag meanings (cross-reference Section 6 of this plan document)
- Privacy note: log files contain file paths, package names, command output, and certificate nicknames. They do not contain PIN values, card serial numbers, private key material, or personally identifiable information. Safe to share in full for support purposes.
- What to include in a bug report: log file, `opensc-tool --list-readers` output, `pacman -Q opensc pcsclite nss ccid` output, and a description of the exact step where the failure occurred.

#### `snapshots.md`

- What a snapshot captures: the current set of certificate registrations and PKCS11 module registrations in every NSS database. Does not capture packages, service state, or log files.
- When to use: before manually editing NSS databases; before a system update that may touch OpenSC or pcsclite; as a recovery point before experimenting with configuration changes.
- Creating: Snapshots panel → "Create Snapshot" → enter a label → confirm. Saved to `/var/lib/cachy_cac/snapshots/`.
- Restoring: Snapshots panel → select snapshot → "Restore" → confirm. Diff-based: adds certificates and modules that are in the snapshot but missing from the current state; removes certificates and modules present in the current state but not in the snapshot. Never modifies packages or services.
- Deleting: Snapshots panel → select → "Delete". Removal is permanent.
- Difference from full reinstall: use a snapshot for cert/PKCS11 configuration drift; use uninstall + reinstall for full package-level reset.

#### `keyboard_shortcuts.md`

| Shortcut | Action |
|---|---|
| `F1` | Open Help dialog |
| `Ctrl+Z` | Undo last configuration change |
| `Ctrl+Y` / `Ctrl+Shift+Z` | Redo |
| `Ctrl+Q` | Quit application |
| `Ctrl+W` | Close current dialog |
| `Escape` | Close modal dialog / cancel pending destructive confirmation |

Additional shortcuts are documented here as Phase 2 main window design is finalized.

#### `about.md`

- Application name and version string (loaded at runtime from `cachy_cac.__version__`)
- License: MIT
- Credits: upstream `linux_cac` project; OpenSC project; DoD PKI certificate authorities
- GitHub repository URL
- How to file a bug report (link to GitHub Issues)
- How to contribute (link to `CONTRIBUTING.md` on GitHub)

---

### 11.6 Dependencies

One additional package beyond the Phase 2 dependency list:

| Package (Arch/CachyOS) | pip name | Purpose |
|---|---|---|
| `python-markdown` | `Markdown` | Markdown-to-HTML conversion; `tables` and `fenced_code` extensions included |

Add to `gui/requirements.txt`. No other new dependencies are introduced by Phase 5.

---

### 11.7 CI Additions for Phase 5

Two CI additions to `ci.yml` are implemented during Phase 5 (not Phase 3):

1. **`markdown-lint` job** — runs `pymarkdownlnt` (`pip install pymarkdownlnt`) on all `gui/help/content/*.md` files. Catches broken heading hierarchy, malformed tables, bare URLs, and trailing whitespace.

2. **`help-index-validate`** — a Python test in `tests/test_orchestrator/test_help_index.py` that:
   - Loads `gui/help/index.json` and verifies JSON is well-formed
   - Confirms every `"file"` field resolves to an existing file in `gui/help/content/`
   - Confirms all topic `"id"` values are unique across the entire index
   - Confirms all `"anchor"` values match the regex `^[a-z0-9-]+$` (valid Markdown heading slug format)
   - Automatically included in the existing `python-tests` CI job via `unittest discover`

---

## 12. CI/CD Infrastructure Completeness

This section audits the complete set of GitHub Actions workflows, repository configuration files, and developer tooling required to manage this project as a fully CI/CD-governed open-source repository. Items in this section supplement Phase 3 (Section 9) and Phase 4 (Section 10). Where a gap exists relative to Phase 3's current plan, it is explicitly noted.

---

### 12.1 Arch Linux Container Job (Supplementing Section 9.1)

**Supplement to Section 9.1:** While GitHub does not provide an *official hosted Arch Linux runner*, it is possible to run Arch Linux using the publicly available `archlinux:latest` Docker image on any `ubuntu-latest` runner via the `container:` key. This enables BATS tests that install real Arch packages (`bash-bats`, `nss`, `opensc`, `pcsclite`) and run against actual Arch binary paths — eliminating the primary limitation identified in Section 9.1.

**Addition to `ci.yml`:** A new `bats-arch` job uses `container: archlinux:latest` to run BATS integration-level unit tests with real Arch packages. This complements the `bats-unit` job (which uses mocks on `ubuntu-latest`) by validating that Bash scripts work correctly with actual Arch binaries and paths.

```yaml
  bats-arch:
    needs: [bash-syntax, shellcheck]
    runs-on: ubuntu-latest
    container: archlinux:latest
    defaults:
      run:
        working-directory: cachy_cac
    steps:
      - uses: actions/checkout@v4
      - name: Install Arch dependencies
        run: |
          pacman -Syu --noconfirm
          pacman -S --noconfirm bash bash-bats nss pcsclite opensc
      - name: Run BATS tests with real Arch packages
        run: bats tests/*.bats
```

**Note on `pacman -Syu` vs `pacman -Sy`:** The full `pacman -Syu` (not `-Sy`) is required in the Arch container — partial upgrades (`-Sy` without `-u`) break Arch's rolling release package dependency integrity. This is consistent with the project-wide requirement documented in Section 3 and the CachyOS-specific notes in `MEMORY.md`.

**Updated Section 9.1 summary:** Both testing paths are valid and complementary:
- `bats-unit` (`ubuntu-latest` + mocks): fast, no external packages, tests logic paths with controlled stubs
- `bats-arch` (`archlinux:latest` container): tests with real Arch binaries and real package paths; catches Arch-specific path or behavior regressions

Full hardware integration tests (real smart card reader, real CAC, real browser login) remain out of scope for hosted CI and require a self-hosted runner as described in Section 9.1.

---

### 12.2 `.github/` Directory Structure

A fully CI/CD-managed project requires more than just workflow files. The complete `.github/` directory layout:

```
.github/
  workflows/
    ci.yml                    # Phase 3 — continuous integration (Section 9.3)
    release.yml               # Phase 3 — tag-triggered release (Section 9.4)
    stale.yml                 # Phase 4 — automated stale issue/PR closure (Section 12.6)
  ISSUE_TEMPLATE/
    bug_report.md             # Structured bug report template (Section 12.3)
    feature_request.md        # Structured feature request template (Section 12.3)
    config.yml                # Disables blank issues; points to Discussions for questions
  pull_request_template.md    # PR checklist template (Section 12.3)
  CODEOWNERS                  # Review assignment (Section 12.4)
  dependabot.yml              # Automated dependency update PRs (Section 12.5)
```

Add this layout to Section 2 (Project Structure) when Phase 3 is implemented.

---

### 12.3 Issue and Pull Request Templates

#### Bug Report Template (`.github/ISSUE_TEMPLATE/bug_report.md`)

```markdown
---
name: Bug Report
about: Report a defect in CachyOS CAC Setup
labels: bug, needs-triage
---

## Description
<!-- A clear description of what went wrong -->

## Environment
- CachyOS version: <!-- output of `uname -r` and `pacman -Qe cachyos-*` -->
- Architecture: <!-- x86_64 or aarch64 -->
- Browser(s) affected: <!-- Firefox / Chromium / Edge / Brave -->
- Application version: <!-- `python3 cac_setup.py --version` output -->

## Steps to Reproduce
1.
2.
3.

## Expected Result

## Actual Result

## Log File
<!-- Paste the relevant portion of /var/log/cachy_cac_*.log (errors and warnings) -->
<!-- Full log is safe to share — it contains no PIN values or private key material -->

## Additional Context
<!-- opensc-tool --list-readers output, pacman -Q opensc pcsclite nss ccid output -->
```

#### Feature Request Template (`.github/ISSUE_TEMPLATE/feature_request.md`)

```markdown
---
name: Feature Request
about: Suggest a new feature or improvement
labels: enhancement, needs-triage
---

## Problem Statement
<!-- What problem does this feature solve? -->

## Proposed Solution
<!-- What should the application do differently? -->

## Alternatives Considered

## Scope
<!-- Which phase does this affect? Phase 1 CLI / Phase 2 GUI / Phase 3 CI -->

## Additional Context
```

#### Issue Template Config (`.github/ISSUE_TEMPLATE/config.yml`)

```yaml
blank_issues_enabled: false
contact_links:
  - name: Ask a Question
    url: https://github.com/<owner>/cachy-cac/discussions
    about: Use GitHub Discussions for questions and general support
```

#### Pull Request Template (`.github/pull_request_template.md`)

```markdown
## Summary
<!-- What does this PR change and why? -->

## Related Issue
Closes #

## Type of Change
- [ ] Bug fix (non-breaking)
- [ ] Enhancement (non-breaking)
- [ ] Breaking change (see Section 10.3.3 of PLAN.md)
- [ ] Documentation only
- [ ] CI/CD only

## Pre-Merge Checklist
- [ ] `shellcheck -x lib/*.sh bash/*.sh` passes locally
- [ ] `bash -n lib/*.sh bash/*.sh` passes locally
- [ ] `ruff check orchestrator/ distros/ *.py` passes locally
- [ ] `bats tests/*.bats` passes locally
- [ ] `python3 -m unittest discover -s tests/test_orchestrator -v` passes locally
- [ ] Install/Uninstall Symmetry Contract maintained (Section 0.4 of PLAN.md)
- [ ] New install action has a corresponding row in the Section 4 symmetry table
- [ ] `CHANGELOG.md` updated if this change will be included in a release

## Breaking Change Details (if applicable)
<!-- What breaks? What is the migration path? -->

## Security Review (if applicable)
<!-- Does this touch lib/certs.sh, lib/import.sh, lib/pkcs11.sh, or orchestrator/runner.py? -->
```

---

### 12.4 CODEOWNERS

`.github/CODEOWNERS` assigns required reviewers. For a single-maintainer project, this is simple initially but establishes the pattern for future contributors:

```
# Global owner — required review on all PRs
*                           @<github-username>

# CI/CD workflows — require explicit review for any workflow changes
.github/workflows/          @<github-username>

# Security-sensitive files — require explicit review
cachy_cac/lib/certs.sh      @<github-username>
cachy_cac/lib/import.sh     @<github-username>
cachy_cac/lib/pkcs11.sh     @<github-username>
cachy_cac/orchestrator/runner.py  @<github-username>
```

Replace `@<github-username>` with the repository owner's GitHub handle when creating the file.

---

### 12.5 Dependabot Configuration

`.github/dependabot.yml` automates pull requests to update pinned GitHub Actions versions when new releases are available. This keeps the CI pipeline on patched versions of `actions/checkout`, `actions/setup-python`, `softprops/action-gh-release`, etc.

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "monthly"    # monthly is sufficient for Actions version bumps
    labels:
      - "ci"
      - "dependencies"
    commit-message:
      prefix: "ci"
```

**Scope:** GitHub Actions versions only. Python package dependencies (Phase 2 GUI packages) are not managed by Dependabot in this project because they are installed from Arch/CachyOS repos via `pacman`, not from PyPI via a `requirements.txt` lock file. If a `requirements.txt` pinning PyPI packages is added in Phase 2, add a `pip` ecosystem entry to this file.

---

### 12.6 Stale Issue and PR Workflow

`.github/workflows/stale.yml` implements the automated stale policy defined in Section 10.2 step 5. Runs on a daily schedule.

```yaml
name: Stale

on:
  schedule:
    - cron: "0 8 * * *"    # daily at 08:00 UTC
  workflow_dispatch:

jobs:
  stale:
    runs-on: ubuntu-latest
    permissions:
      issues: write
      pull-requests: write
    steps:
      - uses: actions/stale@v9
        with:
          stale-issue-message: >
            This issue has had no activity for 30 days since a `needs-info` label
            was applied. It will be closed in 7 days unless updated.
            If you have additional information, please comment to reopen the discussion.
          close-issue-message: >
            Closing due to inactivity. If the issue persists, please open a new report
            with updated information.
          days-before-stale: 30
          days-before-close: 7
          stale-issue-label: "stale"
          # only-labels scopes stale marking to issues awaiting reporter response.
          # Triaged bugs and accepted enhancements are NOT staled automatically.
          only-labels: "needs-info"
          exempt-issue-labels: "security,pinned,bug,enhancement,accepted"
          stale-pr-message: >
            This pull request has had no activity for 45 days. It will be closed
            in 7 days unless updated.
          days-before-pr-stale: 45
          days-before-pr-close: 7
          stale-pr-label: "stale"
          exempt-pr-labels: "security,pinned"
```

**Note:** PRs get a longer stale window (45 days) than issues (30 days) because contributors invest more effort in PRs and deserve more time to respond to review feedback.

---

### 12.7 SECURITY.md

`SECURITY.md` at the repository root documents the process for reporting security vulnerabilities privately before public disclosure.

```markdown
# Security Policy

## Supported Versions

Only the latest release is actively supported with security fixes.

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |
| Older   | No        |

## Reporting a Vulnerability

**Do not file a public GitHub Issue for security vulnerabilities.**

To report a security vulnerability, use GitHub's private vulnerability reporting:
Repository → Security tab → "Report a vulnerability"

Please include:
- A description of the vulnerability
- Steps to reproduce
- The version of cachy-cac affected
- Any relevant log output (redacted as needed)

Security reports are acknowledged within 72 hours. A fix is targeted within
14 days for confirmed vulnerabilities. Out-of-cycle patch releases are made
immediately for confirmed exploitable issues (see Section 10.2 of PLAN.md).
```

---

### 12.8 CONTRIBUTING.md

`CONTRIBUTING.md` at the repository root covers the contribution workflow. Key sections:

1. **Development Setup** — clone the repo; install `shellcheck`, `bash-bats`, `ruff`, `python-markdown` from Arch repos; run the local test suite with `bats tests/*.bats` and `python3 -m unittest discover -s tests/test_orchestrator`

2. **Branch and PR Workflow** — fork the repository; create a feature branch from `main`; open a PR against `main`; all `ci.yml` checks must pass; at least one review required (enforced by branch protection)

3. **Commit Message Style** — imperative mood; present tense; 72-character subject line; reference issue numbers (`Closes #N`)

4. **Per-Item Plan Requirement** — link to Section 10.4 of `PLAN.md`; every non-trivial change requires a written plan comment on the PR before implementation begins

5. **Required Branch Protection Settings** (for repository administrators):
   - Require status checks to pass before merging: `bash-syntax`, `shellcheck`, `python-lint`, `python-tests`, `bats-unit`, `bats-arch`
   - Require branches to be up to date before merging
   - Require at least 1 approving review
   - Do not allow bypassing the above settings
   - Restrict who can push directly to `main`: repository owners only

6. **Code Style** — Bash: ShellCheck-clean; `local` for all function variables; `[[ ]]` for conditionals. Python: `ruff`-clean; stdlib only for Phase 1.

7. **Security-Sensitive Areas** — reference Section 10.3.4 of `PLAN.md` for the list of files requiring elevated review.

---

### 12.9 CHANGELOG.md Format

`CHANGELOG.md` at the repository root follows the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format (`Added`, `Changed`, `Fixed`, `Removed`, `Security`). A `[Unreleased]` section is maintained at the top and flushed to a versioned entry on each release.

```markdown
# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
Versioning: [Semantic Versioning](https://semver.org/)

## [Unreleased]

### Added
### Changed
### Fixed
### Removed
### Security

## [1.0.0] - YYYY-MM-DD

### Added
- Initial release: Phase 1 CLI setup and uninstall for CachyOS

[Unreleased]: https://github.com/<owner>/cachy-cac/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/<owner>/cachy-cac/releases/tag/v1.0.0
```

The `CHANGELOG.md` entry for each release is committed as part of the release commit (before the tag is pushed), consistent with the process described in Section 9.4.

---

### 12.10 Version Management

A single authoritative version string must be defined and kept consistent across the codebase, the git tag, and `CHANGELOG.md`.

**Authoritative location:** `cachy_cac/version.py`

```python
__version__ = "1.0.0"
```

All other references derive from this. Because `cac_setup.py` and `cac_uninstall.py` use `sys.path.insert(0, str(Path(__file__).parent))` to treat `cachy_cac/` as the root, the correct import form inside those files is:
- `cac_setup.py` and `cac_uninstall.py`: `from version import __version__`
- Phase 2 GUI entry point (`gui/main.py`): same — `from version import __version__`
- Phase 5 Help `about.md` description: loaded at runtime via `from version import __version__`

Do not use `from cachy_cac.version import __version__` — that form requires `cachy_cac` to be an installed package, which it is not in the current entry-point model.

**Version bump process** (manual; no automated bump tool):
1. Edit `cachy_cac/version.py` — update `__version__`
2. Edit `CHANGELOG.md` — move `[Unreleased]` content to a new versioned section; update comparison links
3. Commit: `git commit -m "chore: release vX.Y.Z"`
4. Tag: `git tag vX.Y.Z`
5. Push tag: `git push origin vX.Y.Z` — triggers `release.yml`

**Consistency check:** Add a test in `tests/test_orchestrator/test_version.py`. Because CI runs with `working-directory: cachy_cac`, the correct import inside the test is `import version; assert re.match(r'^\d+\.\d+\.\d+$', version.__version__)`. Do not use `from cachy_cac.version import` inside the test. This test is automatically run by the `python-tests` CI job via `unittest discover`.

---

### 12.11 Pre-Commit Hook Configuration

`.pre-commit-config.yaml` at the repository root enables local developer tooling that mirrors CI checks, catching issues before a push. Install with `pip install pre-commit && pre-commit install` (run once after cloning).

```yaml
repos:
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.10.0.1
    hooks:
      - id: shellcheck
        args: ["-x"]
        files: ^cachy_cac/(lib|bash)/.*\.sh$

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.4.4
    hooks:
      - id: ruff
        args: ["--fix"]
        files: ^cachy_cac/.*\.py$

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
        files: ^\.github/.*\.yml$
      - id: check-json
        files: ^cachy_cac/gui/help/index\.json$
```

**Note:** Pre-commit hooks run locally and are not enforced by CI (CI runs the same checks independently). They are a developer convenience, not a CI gate. Running `pre-commit run --all-files` should produce no failures on a clean branch — treat violations from pre-commit as equivalent to CI failures.

**Version pinning:** The `rev:` values in this file (e.g., for `ruff-pre-commit`) will drift from the versions installed by CI (`pip install ruff` without a pin). To keep pre-commit and CI in sync: either pin `ruff` in both places (`pip install ruff==X.Y.Z` in ci.yml and the matching `rev:` here), or run `pre-commit autoupdate` periodically. The authoritative check is CI; if pre-commit passes but CI fails on linting, the ruff versions have diverged. Resolve by pinning both to the same version.

---

### 12.12 Python Version Matrix

The `python-tests` job in `ci.yml` should test against the Python versions users are likely to have on CachyOS at any given time. CachyOS is a rolling release that typically ships a recent Python 3.x.

Add a version matrix to the `python-tests` job:

```yaml
  python-tests:
    strategy:
      matrix:
        python-version: ["3.10", "3.11", "3.12"]
      fail-fast: false    # test all versions even if one fails
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: cachy_cac
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      - name: Unit tests
        run: python3 -m unittest discover -s tests/test_orchestrator -v
```

**Minimum version:** Python 3.10 is the minimum because the codebase uses `X | Y` union type syntax (PEP 604) and `match` is potentially used in future phases. Verify each new language feature against the 3.10 minimum before merging.

---

### 12.13 CI Artifact Upload

Test results and coverage data should be uploaded as GitHub Actions artifacts for inspection when a CI run fails. Add artifact upload steps to the relevant jobs:

```yaml
      - name: Upload test results
        if: always()    # upload even on failure — most useful for debugging failures
        uses: actions/upload-artifact@v4
        with:
          name: test-results-${{ matrix.python-version || 'default' }}
          path: cachy_cac/test-results/
          retention-days: 14
```

**Test result format:** Python `unittest` outputs to stdout by default. To produce a JUnit XML file for artifact upload, use `xmlrunner` (`pip install unittest-xml-reporting`) or redirect `unittest` output. Alternatively, the CI log is sufficient for debugging for a project of this scale — artifact upload of the raw log is acceptable as a simpler alternative.

**Retention:** 14 days is sufficient for a project releasing quarterly. Artifact storage is free within GitHub's quota for public repositories.

---

### 12.14 Branch Protection Summary

The following GitHub repository settings must be configured when Phase 3 CI is activated. These are applied in: Repository → Settings → Branches → Add rule → target `main`.

| Setting | Value |
|---|---|
| Require status checks to pass before merging | Enabled |
| Required checks (Phase 3) | `bash-syntax`, `shellcheck`, `python-lint`, `python-tests` (all matrix versions), `bats-unit`, `bats-arch` |
| Additional required checks (Phase 5) | add `markdown-lint` once Phase 5 is implemented |
| Require branches to be up to date before merging | Enabled |
| Require at least 1 approving review | Enabled |
| Dismiss stale reviews when new commits are pushed | Enabled |
| Require review from CODEOWNERS | Enabled (once CODEOWNERS is configured) |
| Allow force pushes | Disabled |
| Allow deletions | Disabled |

Document this table in `CONTRIBUTING.md` for repository administrators.

---

## Appendix: Critical Files for Implementation

| File | Purpose |
|---|---|
| `linux_cac/cac_setup.sh` | Source Bash script — reference for all original logic |
| `linux_cac/README.md` | Documents known issues; informs what NOT to port |
| `~/.config/mozilla/firefox/*/pkcs11.txt` | Live example of correct `modutil` registration format |
| `~/.pki/nssdb/pkcs11.txt` | Live example of Chromium shared NSS database structure |
| `linux_cac/.github/workflows/CI.yml` | Source CI to adapt for Bash/shellcheck/BATS |
| `cachy_cac/.github/workflows/ci.yml` | Phase 3 CI workflow (planned — not yet created; skeleton in Section 9.3 + 12.1) |
| `cachy_cac/.github/workflows/release.yml` | Phase 3 release automation workflow (planned — not yet created; see Section 9.4) |
| `cachy_cac/.github/workflows/stale.yml` | Phase 4 stale issue/PR automation (planned — skeleton in Section 12.6) |
| `cachy_cac/.github/ISSUE_TEMPLATE/bug_report.md` | Bug report template (planned — template in Section 12.3) |
| `cachy_cac/.github/ISSUE_TEMPLATE/feature_request.md` | Feature request template (planned — template in Section 12.3) |
| `cachy_cac/.github/pull_request_template.md` | PR checklist template (planned — template in Section 12.3) |
| `cachy_cac/.github/CODEOWNERS` | Review assignment (planned — template in Section 12.4) |
| `cachy_cac/.github/dependabot.yml` | Dependabot Actions version bumps (planned — skeleton in Section 12.5) |
| `cachy_cac/tests/mocks/` | BATS mock stubs for system commands (planned — not yet created; see Section 9.2) |
| `cachy_cac/version.py` | Authoritative version string (planned — see Section 12.10) |
| `SECURITY.md` | Vulnerability reporting policy (planned — template in Section 12.7) |
| `CONTRIBUTING.md` | Contribution guidelines and branch protection settings (planned — outline in Section 12.8) |
| `CHANGELOG.md` | Keep a Changelog format; updated on each release (planned — format in Section 12.9) |
| `.pre-commit-config.yaml` | Local developer pre-commit hooks mirroring CI (planned — skeleton in Section 12.11) |
| `cachy_cac/gui/help/help_dialog.py` | Phase 5 HelpDialog class (planned — spec in Section 11.4) |
| `cachy_cac/gui/help/index.json` | Help topic TOC (planned — schema in Section 11.3) |
| `cachy_cac/gui/help/content/` | Help Markdown source files (planned — outline in Section 11.5) |
| `cachy_cac/gui/main.py` | Phase 2 entry point (placeholder — not yet created) |
| `cachy_cac/gui/indicator.py` | Phase 2 system tray integration (placeholder — not yet created) |
| `cachy_cac/gui/requirements.txt` | Phase 2 Python package dependencies (placeholder — not yet created) |
