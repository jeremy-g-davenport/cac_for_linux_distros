# Testing CAC for Linux Distros

> **Policy:** Always test in the CachyOS VM and confirm success there before running anything on your own machine.

There are three levels of testing, from safest to most invasive:

---

## VM Prerequisites (fresh CachyOS install, terminal only)

Before anything else, install the required tools:

```bash
sudo pacman -Syu git github-cli bats python
```

Authenticate with GitHub:

```bash
gh auth login
# Choose: GitHub.com → HTTPS → Login with a web browser
# Follow the one-time code prompt in the browser
```

Clone the repo:

```bash
git clone https://github.com/jeremy-g-davenport/cac_for_linux_distros.git
cd cac_for_linux_distros
```

Set up the Python virtual environment:

```bash
python -m venv .venv
.venv/bin/pip install -r requirements.txt
```

> **Note:** Call `.venv/bin/pip` and `.venv/bin/python` directly instead of sourcing the activate script — this works in any shell (Fish, Bash, Zsh, etc.).

---

## Level 1: Unit Tests (safe — no system changes)

These run entirely with mocks — no real packages installed, no sudo required.

```bash
# BATS unit tests (Bash layer)
bats tests/*.bats

# Python unit tests (orchestrator layer)
.venv/bin/python -m unittest discover -s tests/test_orchestrator -v
```

---

## Level 2: Integration Tests (requires root — snapshot first)

The integration test suite (`tests/integration/test_full_install.bats`) runs a real install + uninstall cycle. It auto-skips unless `CI_INTEGRATION=1` is set, and requires root.

> **Snapshot first.** Take a VirtualBox snapshot before running integration tests so you can roll back cleanly.

```bash
sudo CI_INTEGRATION=1 bats tests/integration/test_full_install.bats
```

---

## Level 3: Manual End-to-End (real CAC card, real VM)

This is the full real-world test. On the CachyOS VM:

```bash
# Install
sudo .venv/bin/python cac_setup.py

# Verify state was written
cat /var/lib/cac_for_linux_distros/state.json
cat /var/lib/cac_for_linux_distros/action_log.json

# Test with a real CAC card (via USB passthrough in VirtualBox)
# Settings → USB → Add filter for your CAC reader

# Uninstall
sudo .venv/bin/python cac_uninstall.py
```

**VirtualBox USB passthrough for the CAC reader:**
- In VirtualBox: `Settings → USB → USB 3.0 Controller` → click the `+` icon and add your CAC reader by name
- Plug the reader in before starting the VM, or hot-attach it after boot

---

## Recommended VM Test Workflow

```
1. Take a snapshot ("pre-test clean state")
2. Run: sudo .venv/bin/python cac_setup.py
3. Insert CAC card → verify browser auth works
4. Run: sudo .venv/bin/python cac_uninstall.py
5. Verify system is clean (check state.json is gone or reset)
6. Restore snapshot for next test run
```

---

## What's currently gated behind `CI_INTEGRATION=1`

The unit tests (`tests/*.bats` and `test_orchestrator/`) run anywhere. The integration test file at `tests/integration/test_full_install.bats` is the only file that needs a real system — it checks for that env var and root before running anything.
