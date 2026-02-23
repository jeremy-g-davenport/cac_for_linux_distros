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

*Add numbered runtime issues below as testing begins.*
