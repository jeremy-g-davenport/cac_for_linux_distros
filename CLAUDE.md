# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

No implementation code exists yet. The repository currently contains:
- `README.md` — project overview
- `cachy_cac/PLAN.md` — the authoritative, fully detailed implementation plan (read this first)
- `cachy_cac/KNOWN_ISSUES.md` — pre-documented issues from prior art, informing design decisions
- `linux_cac/` — upstream Bash/Debian reference script; read-only reference, never copy from it

Both `cachy_cac/` and `linux_cac/` are listed in `.gitignore` and are not tracked by git. Implementation work belongs in `cachy_cac/`.

## Architecture

Three-layer model (all detail in `PLAN.md` Section 0):

```
Layer 1 — Python orchestration  (orchestrator/, distros/, cac_setup.py, cac_uninstall.py)
Layer 2 — Distro abstraction    (distros/arch/driver.py implements DistroDriver ABC)
Layer 3 — Bash execution        (lib/*.sh sourced by bash/install.sh and bash/uninstall.sh)
```

Python calls Bash via subprocess and injects distro-specific values as environment variables. Bash communicates back via two stdout prefixes that Python parses line-by-line:
- `STATE:<key>=<value>` — updates `InstallState` and persists to `/var/lib/cachy_cac/state.json`
- `ACTION:<type>|<field>|...` — appends an `ActionRecord` to `/var/lib/cachy_cac/action_log.json`

`orchestrator/runner.py::stream_bash()` is the shared reuse hook for both the Phase 1 CLI and the Phase 2 GUI — do not add a second subprocess layer in Phase 2.

## Commands

No code exists yet. Once Phase 1 is implemented, the standard commands will be:

```bash
# Python virtual environment — always develop inside a venv; use pip only (not conda/poetry/pipenv)
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt          # Phase 1: ruff, pyinstaller (if applicable)
pip install -r gui/requirements.txt      # Phase 2/5: PyQt6, libayatana-appindicator bindings

# Lint and syntax — run from cachy_cac/ with venv active
shellcheck -x lib/*.sh bash/*.sh
bash -n lib/*.sh bash/*.sh
ruff check orchestrator/ distros/ *.py

# Tests — run from cachy_cac/
bats tests/*.bats                                              # all BATS unit tests
bats tests/test_log.bats                                       # single BATS file
python -m unittest discover -s tests/test_orchestrator -v     # Python unit tests
python -m unittest tests.test_orchestrator.test_runner -v     # single Python test module

# Run the tool (requires sudo; real system — use a VM)
sudo python cac_setup.py
sudo python cac_uninstall.py
```

## Critical Constraints

**Bash**
- All `lib/*.sh` files declare no `set -euo pipefail` themselves — they inherit it from `bash/install.sh` or `bash/uninstall.sh` which source them. Do not add `set -e` to library files.
- All function-scoped variables must use `local`. No global variable leakage.
- Use `[[ ]]` for conditionals, never `[ ]`. Use `$()` for command substitution, never backticks.
- `pacman -Syu` (full sync + upgrade), never `pacman -Sy` (partial upgrade breaks Arch rolling release).

**NSS / browser operations**
- All `certutil` and `modutil` calls run as `$REAL_USER` via `sudo -H -u "$REAL_USER"`, never as root. Files owned by root in a user's NSS database silently break browser CAC authentication.
- `pcscd` uses socket activation: manage `pcscd.socket`, not `pcscd.service`. Both `enable` and `start` must be called — `enable` alone leaves the daemon inactive until reboot.
- Firefox profiles on CachyOS are at `~/.config/mozilla/firefox/`, not `~/.mozilla/firefox/`. `pkcs11-register` silently fails because of this; use `modutil` directly as the primary registration path.

**Variable naming**
- The injected environment variable for the OpenSC library path is `PKCS11_LIB`. `lib/pkcs11.sh` and `lib/verify.sh` alias it as `readonly OPENSC_PKCS11_LIB="${PKCS11_LIB}"` at their top — this alias is local to those two files only.

**Install/uninstall symmetry**
- Every install action must have a documented uninstall counterpart in the Section 4 symmetry table before it is merged. The uninstall flow reads `state.json` and `action_log.json` to reverse only what was actually completed.

## Branch Naming

`p<phase>/<name>` for phase work; `ci/<name>` for repository infrastructure. Full table at the top of `PLAN.md` under "Branch Names". Examples: `p1/packages`, `p1/uninstall`, `p2/main-window`, `p3/ci`, `ci/repo-init`.

## Key Files to Read Before Implementing Any Step

| File | When to read |
|---|---|
| `cachy_cac/PLAN.md` | Before any implementation — contains complete specs, contracts, and code skeletons |
| `cachy_cac/KNOWN_ISSUES.md` | Before working on detection, PKCS11, NSS, or service steps — pre-documented failure modes |
| `linux_cac/cac_setup.sh` | As reference for original logic only — do not port Debian-specific code |

## Department Name

The employing organization is the **DoW** (not DoD — the name has changed). Do not alter this in any file.
