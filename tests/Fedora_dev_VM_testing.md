# Testing CAC for Linux Distros — Fedora VM

> **Policy:** Always test in the Fedora VM and confirm success there before running anything on your own machine.

There are three levels of testing, from safest to most invasive.

---

## VM Prerequisites (fresh Fedora install, terminal only)

Before anything else, install required tools. `bats` is available in the Fedora repos:

```bash
sudo dnf install -y git gh bats python3 python3-pip
```

Authenticate with GitHub:

```bash
gh auth login
# Choose: GitHub.com → HTTPS → Login with a web browser
# Follow the one-time code prompt in the browser
```

Clone the repo and check out the PR branch (before PR #36 is merged):

```bash
git clone https://github.com/jeremy-g-davenport/cac_for_linux_distros.git
cd cac_for_linux_distros
git checkout p1/redhat-distro
```

> After PR #36 is merged, use `main` instead: `git checkout main && git pull`

Set up the Python virtual environment:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

> **Note:** Call `.venv/bin/pip` and `.venv/bin/python` directly instead of sourcing the activate script — this works in any shell.

---

## Step 0: Verify Package Names (Fedora-specific, do this first)

Confirm the `pcsc_scan` utility package name on this Fedora version:

```bash
dnf provides pcsc_scan
```

Expected output (verified on Fedora 43):
```
pcsc-tools-1.7.0-7.fc43.x86_64 : Tools to be used with smart cards and PC/SC
```

The package is `pcsc-tools` — same name as on Arch. If a future Fedora version returns a different package name, update `distros/redhat/config.py::REQUIRED_PACKAGES` before proceeding.

Also confirm all required package names resolve:

```bash
dnf info pcsc-lite ccid opensc nss-tools pcsc-tools unzip wget
```

All seven should resolve without "No match for argument" errors.

---

## Level 1: Unit Tests (safe — no system changes)

These run entirely with mocks — no real packages installed, no sudo required.

```bash
# BATS unit tests (Bash layer)
bats tests/*.bats

# Python unit tests (orchestrator layer)
.venv/bin/python -m unittest discover -s tests/test_orchestrator -v
```

**Expected results:** All BATS and Python tests pass. Key Fedora-specific tests to confirm:

| Test file | What it checks |
|---|---|
| `test_orchestrator/test_redhat_driver.py` | RedHatDriver properties (lib64, dnf, no AUR) |
| `test_orchestrator/test_build_env_redhat.py` | `_build_env()` injects correct Fedora env vars |
| `test_orchestrator/test_distro_detect.py` | `ID=fedora` routes to `RedHatDriver` |
| `tests/test_packages.bats` | Red Hat scenario: dnf makecache + dnf install |
| `tests/test_detect.bats` | certutil absent = warning only; detect_selinux behavior |

---

## Level 2: Integration Tests (requires root — snapshot first)

> **Snapshot first.** Take a VirtualBox snapshot named "pre-integration-test" before running so you can roll back cleanly.

The integration test suite auto-detects the running distro (Arch or Red Hat family), runs a full install + uninstall cycle, and verifies distro-specific paths and packages. It auto-skips unless `CI_INTEGRATION=1` is set and requires root.

The install and uninstall steps stream live output so you can watch `dnf` progress in real time.

```bash
sudo CI_INTEGRATION=1 bats tests/integration/test_full_install.bats
```

---

## Level 3: Manual End-to-End (real CAC card, real VM)

> **Snapshot first.** Take a VirtualBox snapshot named "pre-e2e-test" before this step.

### Install

```bash
sudo .venv/bin/python cac_setup.py
```

Watch the output for phase-by-phase progress. The phases in order are:
1. `preflight` — root check, detect_selinux, browser check
2. `packages` — dnf install only (run `sudo dnf upgrade` manually beforehand if needed)
3. `opensc-conf` — writes `force_card_driver = cac` to `/etc/opensc.conf`
4. `service` — enables and starts `pcscd.socket`
5. `certs` — downloads and extracts DoD AllCerts.zip
6. `import` — imports CA certs into NSS databases
7. `pkcs11` — registers OpenSC PKCS11 module
8. `verify` — cleanup and post-install verification

### Verify state was written

```bash
cat /var/lib/cac_for_linux_distros/state.json
cat /var/lib/cac_for_linux_distros/action_log.json
```

### Uninstall

```bash
sudo .venv/bin/python cac_uninstall.py
```

---

## Fedora-Specific Verification Checklist

Work through these after a successful install. Each item corresponds to a known issue (FN1–FN6) addressed in this release.

### FN1 — certutil not fatal in preflight

In the install output, preflight should **not** exit with an error about `certutil`. Instead it should print a warning like:

```
[WARN] Tool not yet available: certutil (will be installed in packages phase)
```

Then after the packages phase, certutil should be available:

```bash
which certutil
certutil --version
```

### FN2 — PKCS11 library at lib64

Confirm the correct library path was used:

```bash
ls -lh /usr/lib64/opensc-pkcs11.so
```

Confirm the module is registered in the user's NSS database:

```bash
modutil -list -dbdir ~/.pki/nssdb
```

Should list `opensc-pkcs11` pointing to `/usr/lib64/opensc-pkcs11.so`.

Also test with a CAC reader plugged in:

```bash
pkcs11-tool --module /usr/lib64/opensc-pkcs11.so --list-readers
pkcs11-tool --module /usr/lib64/opensc-pkcs11.so --list-objects --login
```

### FN3 — opensc.conf at flat path

Confirm the config was written to the correct (flat) Fedora path:

```bash
grep "force_card_driver" /etc/opensc.conf
```

Expected: `force_card_driver = cac` (uncommented). The file `/etc/opensc/opensc.conf` should not exist (or should not have the setting if it does exist).

### FN4 — Package names resolved correctly

Confirm all packages were installed with correct RPM names:

```bash
rpm -q pcsc-lite ccid opensc nss-tools pcsc-tools unzip wget
```

All seven should return package info, not "package X is not installed".

### FN5 — AUR skipped cleanly

In the install output, packages phase should show:

```
AUR not available on this distro — skipping AUR helper detection.
```

No prompt for `paru`, `yay`, or any other AUR helper should appear.

### FN6 — SELinux status

In the preflight output, look for the SELinux status line. On a default Fedora install with SELinux enforcing:

```
[WARN] SELinux is Enforcing. pcscd policies should be covered by pcsc-lite-selinux.
[WARN] If card access fails after install, run: sudo ausearch -m avc -ts recent
```

After the full install, check for AVC denials that would block CAC access:

```bash
sudo ausearch -m avc -ts recent 2>/dev/null | grep pcscd
```

Ideally: no output (no denials). If denials appear, `pcsc-lite-selinux` may need manual installation:

```bash
sudo dnf install -y pcsc-lite-selinux
sudo systemctl restart pcscd.socket
```

---

## Recommended VM Test Workflow

```
1. Take snapshot "pre-e2e-test"
2. Run: sudo .venv/bin/python cac_setup.py
3. Work through the Fedora-Specific Verification Checklist above
4. Insert CAC card (USB passthrough) → verify browser auth works
5. Run: sudo .venv/bin/python cac_uninstall.py
6. Verify system is clean (state.json gone or reset; rpm -q opensc returns not installed)
7. Restore snapshot for next test run
```

**VirtualBox USB passthrough for the CAC reader:**
- In VirtualBox: `Settings → USB → USB 3.0 Controller` → click the `+` icon and add your CAC reader by name
- Plug the reader in before starting the VM, or hot-attach it after boot

---

## What to Report

If anything fails, note:
- Which phase failed (preflight / packages / opensc-conf / service / certs / import / pkcs11 / verify)
- The exact error line from terminal output
- Output of `getenforce` (SELinux mode)
- Fedora version: `cat /etc/fedora-release`
- Whether the failure corresponds to FN1–FN6 above or is a new issue
