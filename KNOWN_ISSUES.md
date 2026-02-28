# CAC for Linux Distros — Known Issues

This file documents issues discovered during development and testing. Add an entry whenever a test reveals unexpected behavior.

## Entry Format

```markdown
## Issue #N: [Short title]
**Date found:** YYYY-MM-DD
**Step/Function:** Step N — function_name()
**Symptom:** What was observed
**Root cause:** Why it happened
**Fix applied:** What changed in which file
**Verified fixed by:** Test that confirms resolution
```

---

## Pre-Development Known Issues

These issues are documented from prior art before implementation begins.
They inform the design of detection, cleanup, and verification steps.

---

## Issue #P1: Conflicting kernel modules block reader detection
**Source:** [M-Pepper linux-cac-walkthrough](https://github.com/M-Pepper/linux-cac-walkthrough)
**Step/Function:** Step 2 — `detect_conflicting_modules()`
**Symptom:** Card reader is physically connected but `pcsc_scan` and
`opensc-tool --list-readers` report no readers found.
**Root cause:** The `pn533` and `nfc` kernel modules claim the USB device
before `pcscd` can access it.
**Fix applied:** `detect_conflicting_modules()` in `lib/detect.sh` unloads
`pn533` and `nfc` via `modprobe -r` before `pcscd.socket` is started.
**Verified fixed by:** `tests/test_detect.bats` — confirm `opensc-tool --list-readers`
returns a reader after module unload.

---

## Issue #P2: Legacy PKCS11 entries (cackey/coolkey) cause silent auth failures
**Source:** [M-Pepper linux-cac-walkthrough](https://github.com/M-Pepper/linux-cac-walkthrough)
**Step/Function:** Step 9 — `cleanup_legacy_pkcs11()`
**Symptom:** Browser finds no CAC certificates or fails PIN prompt silently
after a fresh OpenSC registration, even though `modutil -list` shows "CAC Module."
**Root cause:** A stale `cackey` or `coolkey` entry registered in the NSS
database points to a library that no longer exists. The browser encounters
the broken entry first and stops searching.
**Fix applied:** `cleanup_legacy_pkcs11()` in `lib/pkcs11.sh` removes any
`CAC Module`, `CACKey`, `coolkey`, or `libcoolkeypk11` entries from each NSS
database before registering the OpenSC module.
**Verified fixed by:** `tests/test_pkcs11.bats` — plant a fake legacy entry,
run cleanup, confirm only the OpenSC entry remains.

---

## Issue #P3: OpenSC does not auto-recognise CAC card without explicit driver config
**Source:** [M-Pepper linux-cac-walkthrough](https://github.com/M-Pepper/linux-cac-walkthrough)
**Step/Function:** Step 4.5 — `configure_opensc_cac_driver()`
**Symptom:** Reader is detected by `pcscd` but `opensc-tool -l` shows the
card as unrecognised or uses the wrong driver.
**Root cause:** `/etc/opensc/opensc.conf` does not force the CAC driver.
OpenSC's auto-detection heuristic can pick a different driver (e.g. `PIV-II`)
which may not support all CAC operations.
**Fix applied:** `configure_opensc_cac_driver()` in `lib/opensc_conf.sh` adds
`card_drivers = cac` and `force_card_driver = cac` to `opensc.conf`.
**Verified fixed by:** `tests/test_opensc_conf.bats` — confirm `opensc-tool -l`
identifies the card as a CAC after config is applied.

---

## Issue #P4: VM USB passthrough of CAC reader blocks host access
**Source:** [Ubuntu community CommonAccessCard wiki](https://help.ubuntu.com/community/CommonAccessCard)
**Step/Function:** Pre-flight / user documentation
**Symptom:** Running `pcsc_scan` on the host returns "token unavailable"
or no reader, even though the hardware is connected.
**Root cause:** A running virtual machine (VMware, VirtualBox, QEMU/USB
passthrough) has claimed exclusive access to the USB reader device.
The host OS loses visibility of the reader while the VM holds it.
**Fix applied:** Not a code fix — documented as a pre-flight warning in
setup output and in the README troubleshooting section.
Mitigation: suspend or disconnect the VM's USB passthrough before running
`cac_setup.py` or using the CAC on the host.
**Verified fixed by:** N/A — user action required.

---

## Issue #P5: `pkcs11-register` silently skips Firefox on CachyOS
**Source:** PLAN.md — W9; linux_cac README
**Step/Function:** Step 9 — `register_pkcs11_all()`
**Symptom:** After setup completes successfully, Firefox does not prompt for
a PIN when visiting CAC-gated sites. Chrome/Chromium works correctly.
`modutil -list` on the Firefox profile database shows no "CAC Module" entry.
**Root cause:** The `pkcs11-register` binary hardcodes `$HOME/.mozilla/firefox`
as its Firefox profile search path. On CachyOS, Firefox stores profiles in
`$HOME/.config/mozilla/firefox/`. `pkcs11-register` finds no profiles and
silently exits 0.
**Fix applied:** `modutil` is used as the primary registration mechanism for
all NSS databases (including Firefox). `pkcs11-register` is called as a
supplemental best-effort step only, with a logged warning that a non-zero
exit is expected on CachyOS for Firefox.
**Verified fixed by:** `tests/test_pkcs11.bats` — confirm "CAC Module" appears
in `modutil -list` output for the Firefox profile database.

---

## Issue #P6: NSS database files owned by root block browser access
**Source:** PLAN.md — `browser.sh` NSS ownership rule
**Step/Function:** Steps 7–9 — any `certutil`/`modutil` call
**Symptom:** Setup completes without error, but all CAC-gated sites fail
silently in all browsers. No PIN prompt appears. `modutil -list` shows the
module is registered when run as root but not as the regular user.
**Root cause:** If `certutil` or `modutil` are run as root against a
user-owned NSS database, the resulting `cert9.db` and `pkcs11.txt` files
are owned by root. The browser process (running as the regular user) cannot
read or write them, silently breaking CAC authentication.
**Fix applied:** All `certutil` and `modutil` calls in `browser.sh`,
`import.sh`, and `pkcs11.sh` use `sudo -H -u "$REAL_USER"` without
exception. The NSS ownership rule is enforced as a global invariant.
**Verified fixed by:** After setup, run `ls -la ~/.pki/nssdb/` and
`ls -la ~/.config/mozilla/firefox/*/`; confirm all NSS files are owned
by the regular user, not root.

---

## Issue #P7: NSS database silent corruption when browsers are open during setup
**Source:** PLAN.md — W18; `browser.sh` `check_browsers_closed()`
**Step/Function:** Step 7 — `check_browsers_closed()`
**Symptom:** Setup completes without error but CAC authentication fails in
one or more browsers. Re-running setup reports "already registered" yet the
browser does not prompt for a PIN.
**Root cause:** Writing to `cert9.db` or `pkcs11.txt` while a browser holds
the file open produces silent no-ops or database corruption. The file is
locked by the browser; writes succeed at the OS level but are silently
discarded or produce a malformed database.
**Fix applied:** `check_browsers_closed()` in `lib/browser.sh` runs
`pgrep` for all supported browsers before any NSS operation. If any browser
process is found, the script exits with a clear error message and the
command to kill them.
**Verified fixed by:** `tests/test_browser.bats` — with a mock browser
process running, confirm `check_browsers_closed()` exits non-zero with
the expected error message.

---

## Issue #P8: `pcscd.socket` enabled but not active until reboot
**Source:** PLAN.md — W17; `service.sh`
**Step/Function:** Step 5 — `enable_pcscd()`
**Symptom:** Setup completes successfully. Card reader is not detected in
the same session. After a reboot, everything works.
**Root cause:** `systemctl enable pcscd.socket` registers the unit for
next boot but does not start it in the current session. The source
`linux_cac` script only calls `enable`, never `start`, so the smart card
daemon is inactive until the next reboot.
**Fix applied:** `enable_pcscd()` in `lib/service.sh` calls both
`systemctl enable pcscd.socket` and `systemctl start pcscd.socket`
so the daemon is operational in the same session.
**Verified fixed by:** `tests/test_service.bats` — after `enable_pcscd`,
confirm `systemctl is-active pcscd.socket` returns "active" without
requiring a reboot.

---

## Issue #P9: `AllCerts.zip` SHA-256 checksum changes after DoD bundle refresh
**Source:** PLAN.md — W5; `certs.sh`
**Step/Function:** Step 6 — `validate_cert_bundle()`
**Symptom:** After a DoD certificate bundle update, `validate_cert_bundle`
logs a checksum mismatch warning on every run. Setup still completes
(mismatch is non-fatal) but the warning is alarming to users.
**Root cause:** DoD periodically publishes a new `AllCerts.zip` bundle.
The `KNOWN_CERT_SHA256` baseline in `lib/certs.sh` becomes stale.
**Fix applied:** Mismatch is logged as a warning (not an error) with
explicit instructions to update `KNOWN_CERT_SHA256` after verifying the
new bundle. Developers must run `sha256sum AllCerts.zip` after each DoD
bundle release and update the constant.
**Verified fixed by:** After updating `KNOWN_CERT_SHA256`, re-run
`validate_cert_bundle`; confirm "Checksum verified" is logged.

---

## Issue #P10: Firefox profile creation race condition on first headless run
**Source:** PLAN.md — W7; `browser.sh` `_ensure_firefox_profile()`
**Step/Function:** Step 7 — `_ensure_firefox_profile()`
**Symptom:** On slow systems or VMs, setup fails with "No Firefox profile
database found" even though Firefox is installed. The error occurs on the
first-ever run when no profile exists yet.
**Root cause:** The source `linux_cac` script launches Firefox headlessly
and then uses `sleep 3` to wait for the profile to initialize. On slow
systems Firefox may take longer than 3 seconds to create `cert9.db`,
causing the subsequent `find` to return empty.
**Fix applied:** `_ensure_firefox_profile()` in `lib/browser.sh` replaces
`sleep` with a polling loop that checks for `cert9.db` every 0.5 seconds
for up to 30 seconds, then kills the headless Firefox process.
**Verified fixed by:** `tests/test_browser.bats` — mock a delayed profile
creation (>3s); confirm the polling loop waits and succeeds rather than
failing immediately.

---

## Issue #1: `source .venv/bin/activate` fails in Fish shell
**Date found:** 2026-02-23
**Step/Function:** VM setup / developer workflow (not install code)
**Symptom:** Running `source .venv/bin/activate` in Fish (Konsole, KDE, CachyOS default)
produces: *"case" builtin not inside of switch block* at line 40 of the activate script.
**Root cause:** `.venv/bin/activate` is a Bash script. Fish cannot source it.
Python venvs ship a Fish-specific `activate.fish`, but relying on per-shell
scripts requires knowing the user's shell in advance.
**Fix applied:** `tests/CachyOS_dev_VM_testing.md` updated to call venv executables
directly by path (`.venv/bin/pip`, `.venv/bin/python`) throughout, eliminating
any need to source an activation script. Works in any shell.
**Verified fixed by:** GitHub issue #21 — confirmed on fresh CachyOS VM in Fish.

---

## Issue #2: `detect_aur_helper` BATS tests fail when `paru` is installed on the host
**Date found:** 2026-02-24
**Step/Function:** `tests/test_aur.bats` — `detect_aur_helper falls back to yay when paru is absent`
  and `detect_aur_helper sets _AUR_HELPER to empty when no AUR helper found`
**Symptom:** Two tests that should hide `paru` from `PATH` continued to find it
  and set `_AUR_HELPER="paru"`, causing assertion failures.
  First observed on a CachyOS development VM (Oracle VirtualBox) where `paru`
  is installed as part of the default CachyOS package set.
**Root cause:** The fallback test filtered `PATH` entries using
  `grep -v paru`, which removes only directories whose *name* contains the
  string "paru".  On CachyOS, `paru` is installed in `/usr/bin` — a directory
  whose name does not contain "paru" — so `/usr/bin` survived the filter and
  `command -v paru` still resolved to the real binary.
  The "no helper" test relied on the inherited mock `PATH` from `_use_mocks()`
  not containing `paru` or `yay`, which is true in a clean container but not
  on a developer machine where those helpers are installed system-wide.
**Fix applied:** `tests/test_aur.bats` — replaced the fragile `grep`-based
  PATH filter with a fully self-contained minimal PATH for each affected test:
  - Fallback test: `PATH="$yay_dir"` (only `yay` present; no system dirs).
  - No-helper test: `PATH="$empty_dir"` (empty temp dir; nothing resolvable).
  Since `detect_aur_helper` only calls `command -v paru` / `command -v yay`
  and sourced Bash functions (`log_info`, `log_warn`), no other PATH entries
  are needed.
**Verified fixed by:** Issue #23 — confirmed on CachyOS VM (Oracle VirtualBox)
  via `bats tests/test_aur.bats`; all 5 tests pass.

---

## Issue #2: `orchestrator/setup_flow.py` PHASES list out of sync with `bash/install.sh`
**Date found:** 2026-02-24
**Step/Function:** `orchestrator/setup_flow.py::run_setup()` — Level 2 integration test
**Symptom:** All three tests in `tests/integration/test_full_install.bats` failed when
  run on a CachyOS development VM (Oracle VirtualBox) with `sudo CI_INTEGRATION=1 bats`:
  `full install completes without errors`, `verify_pcscd_service returns active after
  install`, and `full uninstall completes without errors` all exited non-zero.
**Root cause:** The `PHASES` list in `orchestrator/setup_flow.py` contained `"browser"`
  (which has no corresponding `--phase=browser` case in `bash/install.sh`) and was
  missing `"opensc-conf"` (which is a real phase in `install.sh` responsible for writing
  `force_card_driver = cac` to `/etc/opensc/opensc.conf`).  When the orchestrator reached
  `--phase=browser`, `install.sh` hit the `*)` catch-all, printed `[ERROR] Unknown phase`
  to stderr, and exited 1.  `stream_bash()` raised `CalledProcessError`, which propagated
  uncaught through `run_setup()` and `cac_setup.py`, terminating the install with a
  non-zero exit status.  The missing `opensc-conf` phase meant OpenSC CAC driver
  configuration was silently skipped in the Python-orchestrated path (though it was
  executed correctly in the `--phase=all` standalone escape hatch).
**Fix applied:** `orchestrator/setup_flow.py` — replaced the stale 7-entry PHASES list
  with the correct 8-entry list that mirrors the `--phase=all` sequence in `install.sh`:
  `preflight → packages → opensc-conf → service → certs → import → pkcs11 → verify`.
  Added an inline comment directing developers to cross-check against `--phase=all`
  in `install.sh` whenever the phase list is modified.
**Verified fixed by:** Issue #25 — confirmed on CachyOS VM (Oracle VirtualBox)
  via `sudo CI_INTEGRATION=1 bats tests/integration/test_full_install.bats`.

---

## Issue #3: PID-based staging directory breaks certificate import across phase subprocesses
**Date found:** 2026-02-23
**Step/Function:** `lib/certs.sh::extract_certs()` → `lib/import.sh::import_all_certs()`
  and `lib/certs.sh::cleanup_certs()` (called in `--phase=verify`)
**Symptom:** All three Level 2 integration tests failed on a freshly re-cloned CachyOS
  development VM (Oracle VirtualBox) after `orchestrator/setup_flow.py` PHASES list
  was corrected (Issue #2). The install log was virtually empty because the failure
  occurred early in the `--phase=import` subprocess.
  `import_all_certs` logged `[ERROR] No certificate files available. Run extract_certs
  first.` and exited 1. `stream_bash()` raised `CalledProcessError`, which propagated
  through `run_setup()` and terminated the install. Tests 2 and 3 then failed as
  downstream consequences of test 1 failing.
**Root cause:** `lib/certs.sh` declared `DWNLD_DIR="/tmp/cac_for_linux_distros_$$"` as
  a module-level variable (sourced at load time). `$$` expands to the PID of the current
  bash process. The Python orchestrator runs each install phase as a **separate bash
  subprocess** via `bash bash/install.sh --phase=<name>`. Each subprocess has a unique
  PID, so:
  - `--phase=certs` creates `/tmp/cac_for_linux_distros_<PID1>/` and populates
    `CERT_FILES` in memory.
  - `--phase=import` evaluates `DWNLD_DIR` as `/tmp/cac_for_linux_distros_<PID2>/`
    (a different, non-existent path). Its `CERT_FILES` array is always empty (variables
    do not cross subprocess boundaries). `import_all_certs` exits 1.
  - `--phase=verify` calls `cleanup_certs` against `/tmp/cac_for_linux_distros_<PID3>/`
    — also non-existent; the staging directory is never cleaned up.
  BATS unit tests were unaffected because `tests/test_certs.bats::setup()` explicitly
  overrides `DWNLD_DIR="$BATS_TMPDIR/cac_test_$$"`, masking the bug. The `--phase=all`
  standalone escape hatch was also unaffected because all phases run within a single
  subprocess that shares one PID throughout.
**Fix applied:**
  1. `lib/certs.sh` — replaced `DWNLD_DIR="/tmp/cac_for_linux_distros_$$"` with
     `DWNLD_DIR="${DWNLD_DIR:-/tmp/cac_for_linux_distros_staging}"`. The guard preserves
     the existing BATS override behaviour (BATS sets `DWNLD_DIR` before sourcing, so the
     `:-` default is never used in unit tests). The fixed path is accessible by all phase
     subprocesses.
  2. `lib/import.sh::import_all_certs()` — added a re-scan block before the empty-check
     exit: if `CERT_FILES` is empty and `$DWNLD_DIR/$CERT_DIR_NAME` exists on disk,
     `mapfile` repopulates `CERT_FILES` from a `find` of that directory. This provides a
     defensive fallback for any future scenario (e.g., snapshot restore) where the staging
     directory is present but the in-memory array is empty.
**Verified fixed by:** Issue #27 — confirmed on CachyOS VM (Oracle VirtualBox) via
  `sudo CI_INTEGRATION=1 bats tests/integration/test_full_install.bats`; all 3 tests pass.

---

## Issue #4: Three bugs block integration tests and silently break install correctness
**Date found:** 2026-02-25
**Step/Function:** `bash/install.sh` / `bash/uninstall.sh` startup, `orchestrator/setup_flow.py`,
  `lib/browser.sh`
**Symptom:** All three Level 2 integration tests in `tests/integration/test_full_install.bats`
  continued to fail after the Issue #3 fix (PR #28). The install log was virtually empty because
  the failure occurred before any phase logic ran. Additionally, even when the install appeared to
  succeed, the PKCS11 module was not registered in any NSS database, and the uninstall flow could
  not remove imported certificates or PKCS11 registrations.
**Root cause:** Three independent bugs, all masked by the BATS unit-test harness:

  **Bug 4a (TEST-BLOCKING): `validate_env` called before `log_init` in `bash/install.sh` and
  `bash/uninstall.sh`.**
  `lib/log.sh` initialises `_CAC_LOG_FILE=""` at source time when the variable is unset. Python
  never injects `_CAC_LOG_FILE` into the subprocess environment. `validate_env()` (called first)
  ends with `log_info "Environment validated..."`, which calls `echo "..." >> "$_CAC_LOG_FILE"`.
  With `_CAC_LOG_FILE=""`, bash produces "ambiguous redirect" and exits 1. Under `set -euo
  pipefail` (declared in `install.sh`/`uninstall.sh`) this terminates the script immediately,
  before any phase logic runs. `stream_bash()` raises `CalledProcessError` → `cac_setup.py`
  crashes with a non-zero exit → all integration tests fail.
  BATS unit tests were unaffected because `_setup_test_env()` explicitly sets
  `_CAC_LOG_FILE="$(mktemp)"` before any lib file is sourced.

  **Bug 4b (CORRECTNESS — uninstall): `STATE:imported_cert_nicknames+=` and
  `STATE:pkcs11_registered_in+=` lines silently dropped by Python.**
  `lib/import.sh` emits `echo "STATE:imported_cert_nicknames+=$cert_name"` per imported cert;
  `lib/pkcs11.sh` emits `echo "STATE:pkcs11_registered_in+=$db_dir"` per registered database.
  `setup_flow.py::_parse_line()` splits on the first `=`, producing key
  `imported_cert_nicknames+` / `pkcs11_registered_in+`. Neither key matched any `elif` branch in
  `_apply_state()`, so every emitted value was silently dropped. `state.imported_cert_nicknames`
  and `state.pkcs11_registered_in` were always empty in `state.json` after install. The uninstall
  flow calls `_state_read_list()` to read these lists and reverse those specific changes; with
  empty lists it silently did nothing, leaving DoD CA certs and the PKCS11 module registered even
  after uninstall completed successfully.

  **Bug 4c (CORRECTNESS — install): `NSS_DATABASES` empty in `pkcs11` and `verify` phases.**
  `lib/browser.sh` initialises `NSS_DATABASES=()` at module level; it is populated only by
  `discover_databases()`, which is called only in `--phase=import`. The `--phase=pkcs11` and
  `--phase=verify` phases call `register_pkcs11_all()` and `verify_pkcs11_registered()`, both of
  which loop over `NSS_DATABASES`. Because that array is always empty in those subprocesses, PKCS11
  registration is silently skipped for every NSS database. The tool appeared to succeed (exit 0)
  but no OpenSC module was registered, so CAC authentication would not work in any browser.
  Separately, `setup_flow.py::run_setup()` built the env dict once before the phase loop, so
  `NSS_DB_PATHS` (derived from `state.nss_databases`, which is populated by the import phase) was
  never injected for the pkcs11 or verify phases.

**Fix applied:**
  1. `bash/install.sh` and `bash/uninstall.sh` — swapped `validate_env` and `log_init` so the log
     file is created before any function tries to write to it.
  2. `orchestrator/setup_flow.py::_apply_state()` — added `elif key == "imported_cert_nicknames+":`
     and `elif key == "pkcs11_registered_in+":` branches that call `.append(val)` on the
     corresponding state list, matching the `+=` emit pattern in the bash libs.
  3. `orchestrator/setup_flow.py::run_setup()` — moved `env = _build_env(...)` inside the phase
     loop so every phase receives an env dict that reflects the latest `state` (including
     `NSS_DB_PATHS` after the import phase sets `state.nss_databases`).
  4. `lib/browser.sh` — added a module-level fallback block after `NSS_DATABASES=()` that reads
     `NSS_DB_PATHS` (the colon-separated string injected by Python) and populates `NSS_DATABASES`
     from it when the array would otherwise be empty. This allows the pkcs11 and verify phases to
     operate on the correct databases without re-running `discover_databases()`.
**Verified fixed by:** Issue #27 (reopened) — PR `p1/fix-install-flow-bugs`. New unit tests:
  `tests/test_browser.bats` — two new tests for `NSS_DB_PATHS` → `NSS_DATABASES` conversion.
  `tests/test_orchestrator/test_setup_flow.py` — eight new tests for `_apply_state` `+=` handlers
  and `_build_env` `NSS_DB_PATHS` inclusion.

---

## Issue #5: Three bugs cause Level 3 manual end-to-end test failure
**Date found:** 2026-02-24
**Step/Function:** `lib/opensc_conf.sh::configure_opensc_cac_driver()`, `lib/browser.sh::discover_databases()`,
  `lib/pkcs11.sh::register_pkcs11_all()`, `lib/verify.sh::verify_pkcs11_registered()`
**Symptom:** After a clean `cac_setup.py` install on a CachyOS VM with USB-passthrough card reader,
  both Firefox and Chrome return "Certificate validation failed" on portal.apps.mil and
  rdweb.wvd.azure.us. No certificate selection dialog appears. `state.json` and `action_log.json`
  are created and populated. Card reader is detected by lsusb. Chrome was installed by the user
  after `cac_setup.py` completed.
**Root cause:** Three independent bugs:

  **Bug 5a (CRITICAL — causes Firefox to fail): `configure_opensc_cac_driver` fooled by
  commented-out default opensc.conf directive.**
  The Arch/CachyOS `opensc` package ships `/etc/opensc/opensc.conf` with a commented-out line:
  `    # force_card_driver = cac;`
  The idempotency check `grep -q "force_card_driver"` matches the comment and reports "already
  configured", returning 0 without writing the active directive. OpenSC then uses its card
  auto-detection heuristic, which may select the PIV-II driver instead of the CAC driver. With
  the wrong driver, OpenSC cannot read the card → the PKCS11 module returns no tokens → browsers
  cannot find the client certificate → the portal receives no cert and reports "Certificate
  validation failed". The install log shows "OpenSC CAC driver forcing already configured" even
  though the config is still commented out.

  **Bug 5b (CORRECTNESS — causes Chrome to fail): `~/.pki/nssdb` not created when Chromium is
  absent at install time.**
  `discover_databases()` only calls `_ensure_nssdb()` and adds `~/.pki/nssdb` to `NSS_DATABASES`
  when `CHROMIUM_ANY_FOUND=true`. If Chrome or Chromium is not installed when `cac_setup.py`
  runs, the shared NSS database is never created, the PKCS11 module is never registered in it,
  and DoD root CAs are never imported into it. When the user later installs Chrome (a common
  sequence: install CAC setup first, then install browsers), Chrome's NSS database is unconfigured
  and it cannot use the CAC.

  **Bug 5c (SILENT FAILURE): `register_pkcs11_all` and `verify_pkcs11_registered` succeed silently
  with an empty `NSS_DATABASES` array.**
  If `NSS_DATABASES` is empty (e.g., `NSS_DB_PATHS` was not injected, or the import phase failed
  to populate `state.nss_databases`), the for-loop iterates zero times, `$bad` stays 0, and both
  functions return 0 — falsely reporting PKCS11 registration succeeded / verification passed.

**Fix applied:**
  1. `lib/opensc_conf.sh` — replaced `grep -q "force_card_driver"` with a regex that only matches
     UNCOMMENTED `force_card_driver = cac` lines:
     `grep -qE "^[[:space:]]*force_card_driver[[:space:]]*=[[:space:]]*['\"]?cac['\"]?"`.
     The function now correctly adds the active directive even when the default commented-out
     example is already in the file.
  2. `lib/browser.sh::discover_databases()` — removed the `if [[ "$CHROMIUM_ANY_FOUND" == true ]]`
     guard around `_ensure_nssdb()`. `~/.pki/nssdb` is now always created and always added to
     `NSS_DATABASES`, regardless of which browsers are installed. This future-proofs the install
     against browsers added after setup runs.
  3. `lib/pkcs11.sh::register_pkcs11_all()` — added a guard that exits 1 with a clear error if
     `${#NSS_DATABASES[@]} -eq 0` is reached after the PKCS11 library check. Prevents silent
     no-op from propagating as success.
  4. `lib/verify.sh::verify_pkcs11_registered()` — added the same guard: returns 1 with an error
     log if `NSS_DATABASES` is empty, instead of returning 0 (nothing checked is not a pass).
  5. (Bug 5d — discovered during Level 3 re-test) `lib/opensc_conf.sh` — removed the early
     `return 0` when `$OPENSC_CONF` is missing. The Arch/CachyOS `opensc` package does NOT ship
     a default `/etc/opensc/opensc.conf`, so the old guard silently skipped the entire function.
     Now the function creates the file and directory from scratch using `mkdir -p` + `printf`, then
     returns 0. This is the actual root cause of the Level 3 Firefox failure: without this fix,
     OpenSC never received `force_card_driver = cac` and used its auto-detection heuristic, which
     selected the wrong driver. The test "warns and returns 0 when file missing" was replaced with
     "creates opensc.conf with force_card_driver when file is missing".
**Verified fixed by:** Issue #30 — PR `p1/fix-opensc-conf-and-nssdb`. New BATS tests:
  `tests/test_opensc_conf.bats` — commented-out directive triggers active-line insertion;
     file-absent case now creates a new file with the active directive.
  `tests/test_browser.bats` — nssdb always added to NSS_DATABASES even with no Chromium.
  `tests/test_pkcs11.bats` — register_pkcs11_all exits non-zero with empty NSS_DATABASES.
  `tests/test_verify.bats` — verify_pkcs11_registered returns non-zero with empty NSS_DATABASES.

---

## Issue #5e: pcscd fails with LIBUSB_ERROR_ACCESS after ccid install
**Date found:** 2026-02-24
**Step/Function:** Step 5 — `enable_pcscd()` in `lib/service.sh`
**Symptom:** After a clean `cac_setup.py` install, `opensc-tool --list-readers` returns
  "No smart card readers found" even though the reader is visible in `lsusb`. `pcscd.socket`
  and `pcscd.service` are both active. `journalctl -u pcscd.service` shows:
  `ccid_usb.c:OpenUSBByName() Can't libusb_open(1/8): LIBUSB_ERROR_ACCESS`
  on every pcscd.service start, including manual `systemctl restart` attempts.
  Confirmed with Realtek Smart Card Reader Interface (`0bda:0165`) on CachyOS VM
  (VirtualBox USB passthrough).
**Root cause:** Three compounding factors:
  1. **pcscd runs as non-root**: `pcscd.service` declares `User=pcscd`. libusb calls
     `open("/dev/bus/usb/001/008", O_RDWR)`; the device node has `crw-rw-r-- root:root`
     (others = read-only), so pcscd's open returns `EACCES` → `LIBUSB_ERROR_ACCESS`.
  2. **`pacman`'s hook does not trigger**: After installing pcsclite/ccid, pacman's
     post-transaction hook runs `udevadm control --reload` (reloads rules into kernel)
     but NOT `udevadm trigger`. The already-connected reader keeps its pre-install
     device-node permissions (group=root) indefinitely.
  3. **Class-based rule only fires on `ACTION=="add"`**: `92_pcscd_ccid.rules` contains
     `ENV{ID_USB_INTERFACES}=="*:0b0000:*", GROUP="pcscd"`, which matches CCID class
     devices. The device has `E: ID_USB_INTERFACES=:0b0000:` (confirmed via `udevadm
     info`), so the rule WOULD match — but it only fires on `ACTION=="add"`. The default
     `udevadm trigger` uses `ACTION=="change"`, which does not fire that rule. The
     device group therefore stays `root` even after a trigger, and pcscd still cannot
     open it.
  The issue persists across `pcscd.service` restarts because device permissions are only
  updated when a matching udev rule fires; the device never gets an `add` event again
  until physically reconnected.
**Fix applied:** `lib/service.sh` — two-part fix in `enable_pcscd()`:
  1. **`_write_ccid_udev_rules()`** — new helper scans `/sys/bus/usb/devices/*:*/` for
     interfaces with `bInterfaceClass == 0b` (CCID), reads the parent device's `idVendor`
     and `idProduct` from sysfs, and writes per-device rules to
     `/etc/udev/rules.d/99-cac-ccid.rules`:
     `ATTRS{idVendor}=="XXXX", ATTRS{idProduct}=="YYYY", GROUP="pcscd"`
     VID:PID rules fire on both `add` AND `change`, bypassing the `ACTION=="add"`
     restriction. Works for any CCID reader without requiring a device-specific list.
  2. **`udevadm trigger --action=add --subsystem-match=usb`** — uses `ACTION==add`
     explicitly so the class-based rule in `92_pcscd_ccid.rules` also fires, providing
     belt-and-suspenders coverage for readers not yet in sysfs at scan time.
  `disable_pcscd()` removes `/etc/udev/rules.d/99-cac-ccid.rules` and reloads rules.
**Verified fixed by:** `tests/test_service.bats`:
  - `enable_pcscd triggers udev USB rules with --action=add for card reader access`
    confirms `udevadm trigger --action=add` is called.
  - `_write_ccid_udev_rules creates the rules file` confirms the file is created.
  - `enable_pcscd calls systemctl enable and start for socket and service` confirms
    `pcscd.service` is started explicitly after the trigger.

---

*Add numbered runtime issues below as testing begins.*

---

## Red Hat / Fedora Family Issues (pre-documented, 2026-02-28)

The following issues were identified during design of Red Hat family support and addressed in `p1/redhat-distro`. They are documented here for reference during Fedora VM testing.

---

### FN1 — `certutil`/`modutil` not found in preflight on fresh Fedora

**Date:** 2026-02-28
**Status:** Fixed
**Symptom:** Preflight phase exits with `E_NODEPS` — "Required tool not found: certutil" on a fresh Fedora system without `nss-tools` pre-installed.
**Root cause:** `detect_required_tools()` in `lib/detect.sh` originally included `certutil` and `modutil` in the fatal tool-check loop. On Arch, `nss` (which ships these binaries) tends to be pre-installed as a system dependency. On Fedora, `nss-tools` is a separate optional package.
**Fix:** Moved `certutil` and `modutil` out of the fatal loop. They are now checked with a warning-only path: `log_warn "Tool not yet available: $tool (will be installed in packages phase)"`. The fatal check happens post-install via `verify_certutil()` in the packages phase.
**Verification:** `tests/test_detect.bats` — "detect_required_tools succeeds even when certutil is absent from PATH"

---

### FN2 — PKCS11 library at `/usr/lib64/` not `/usr/lib/`

**Date:** 2026-02-28
**Status:** Fixed (by design)
**Symptom:** OpenSC PKCS11 module not found at `/usr/lib/opensc-pkcs11.so` on Fedora; browser and `pkcs11-tool` cannot load it.
**Root cause:** Red Hat family distributions follow the multiarch convention and place 64-bit native libraries in `/usr/lib64/`. The Arch path `/usr/lib/opensc-pkcs11.so` does not exist on Fedora.
**Fix:** `distros/redhat/config.py` sets `PKCS11_LIB = "/usr/lib64/opensc-pkcs11.so"`, injected by Python as `PKCS11_LIB` env var.
**Verification:** Integration test — `pkcs11-tool --list-readers` and `modutil -list -dbdir ~/.pki/nssdb` should show the module loaded.

---

### FN3 — `opensc.conf` path differs on Fedora

**Date:** 2026-02-28
**Status:** Fixed (by design)
**Symptom:** OpenSC does not pick up `force_card_driver = cac` setting; CAC card uses PIV-II driver instead of CAC driver.
**Root cause:** Fedora's `opensc` RPM compiles with the config path `/etc/opensc.conf` (flat). Arch uses `/etc/opensc/opensc.conf` (subdirectory). Writing to the wrong path has no effect.
**Fix:** `distros/redhat/config.py` sets `OPENSC_CONF = "/etc/opensc.conf"`. Python injects this as the `OPENSC_CONF` env var. `lib/opensc_conf.sh` already has a `[[ -v OPENSC_CONF ]] || OPENSC_CONF="/etc/opensc/opensc.conf"` guard; the injected value takes precedence.
**Verification:** After install, check `/etc/opensc.conf` contains `force_card_driver = cac` (uncommented).

---

### FN4 — Package name differences on Fedora

**Date:** 2026-02-28
**Status:** Fixed (by design)
**Symptom:** `dnf install pcsclite nss` fails — package names do not exist in Fedora repositories.
**Root cause:** Fedora RPM naming differs from Arch:
- `pcsclite` → `pcsc-lite` (hyphen, not concatenated)
- `nss` → `nss-tools` (`certutil`/`modutil` are in the `-tools` subpackage)
- `pcsc-tools` → `pcsc-lite-utils` (pcsc_scan and friends)
**Fix:** `distros/redhat/config.py::REQUIRED_PACKAGES` uses the correct Fedora package names.
**Note:** Verify `pcsc-lite-utils` package name on target Fedora version: `dnf provides pcsc_scan`
**Verification:** After packages phase, `rpm -q pcsc-lite ccid opensc nss-tools` all return 0.

---

### FN5 — No AUR helper on Fedora; AUR detection must be skipped

**Date:** 2026-02-28
**Status:** Fixed
**Symptom:** `detect_aur_helper()` hangs or errors on Fedora; no `paru` or `yay` equivalent exists.
**Root cause:** The packages phase unconditionally called `detect_aur_helper()`, which is an Arch-specific function.
**Fix:** `RedHatDriver.has_aur` returns `False`. Python injects `HAS_AUR=0`. `bash/install.sh` guards the call: `if [[ "${HAS_AUR:-0}" == "1" ]]; then detect_aur_helper; fi`.
**Verification:** Packages phase completes without AUR-related errors on Fedora.

---

### FN6 — SELinux enforcement may silently block pcscd access

**Date:** 2026-02-28
**Status:** Informational warning added; requires VM testing to confirm
**Symptom:** pcscd socket activates but browsers cannot communicate with it under SELinux enforcing mode; card reader reported but authentication fails.
**Root cause:** Fedora ships with SELinux enforcing by default. The `pcscd` daemon runs as `pcscd_t`. Browser PKCS11 loading involves domain transitions that may be denied by SELinux policy depending on whether `pcsc-lite-selinux` policy is installed.
**Fix:** `detect_selinux()` added to `lib/detect.sh`. Called from preflight phase. Emits a warning when `getenforce` returns "Enforcing", directing users to `ausearch -m avc -ts recent` if card access fails. Modern Fedora's `pcsc-lite` RPM includes the selinux subpackage.
**Verification:** On Fedora VM: `getenforce` shows Enforcing; after install, `pkcs11-tool --list-objects --login` succeeds without AVC denials in `ausearch -m avc -ts recent`.
