# Contributing to CAC for CachyOS

Thank you for your interest in contributing. This project manages smart card
authentication for government employees, so code quality and correctness matter
more than speed of contribution.

---

## Requesting Collaborator Access

**Direct PRs from forks are not accepted.** To contribute, you must first be
granted collaborator access on the repository.

To request access:

1. Open a GitHub Issue titled **"Collaborator access request — \<your GitHub username\>"**
2. In the body, briefly describe:
   - Your background (distro experience, CAC/smart card experience, relevant skills)
   - Which part of the project you want to work on (Phase, specific step, or issue number)
   - Any prior contributions to related open-source projects (optional but helpful)
3. Wait for a response from the maintainer before doing any branch work.

Access requests that skip this step will be closed without review.

---

## Development Environment

All development happens inside `cachy_cac/`. Work in a Python virtual environment:

```bash
cd cachy_cac
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Use `pip` only — not conda, poetry, or pipenv.

If you have [direnv](https://direnv.net/) installed, the venv activates
automatically when you `cd` into the project root (see `.envrc`).

---

## Branch Naming

All branches must follow the project convention:

| Pattern | Use |
|---|---|
| `p<N>/<name>` | Phase work (e.g. `p1/packages`, `p2/main-window`) |
| `ci/<name>` | Repository infrastructure (e.g. `ci/shellcheck`) |

Create your branch from `main` after your collaborator access request is
approved. Do not open branches speculatively.

---

---

## Code Standards

**Bash (`lib/*.sh`)**
- No `set -euo pipefail` in library files — they inherit it from entry-point scripts.
- All function-scoped variables must use `local`.
- Use `[[ ]]` for conditionals, `$()` for command substitution.
- `pacman -Syu` only — never `pacman -Sy` (partial upgrades break rolling release).

**NSS / browser operations**
- All `certutil` and `modutil` calls must run as `$REAL_USER` via
  `sudo -H -u "$REAL_USER"`, never as root.
- Manage `pcscd.socket` (not `pcscd.service`) — both `enable` and `start` are required.

**Install/uninstall symmetry**
- Every install action requires a documented uninstall counterpart in the
  Section 4 symmetry table in `PLAN.md` before it can be merged.

**Python**
- Lint with `ruff check` before committing.
- No new dependencies without prior discussion in your access request or the
  relevant issue.

---

## Running Tests and Lint

Run these from `cachy_cac/` with the venv active:

```bash
# Lint
shellcheck -x lib/*.sh bash/*.sh
bash -n lib/*.sh bash/*.sh
ruff check orchestrator/ distros/ *.py

# Unit tests
bats tests/*.bats
python -m unittest discover -s tests/test_orchestrator -v
```

All tests and lint checks must pass before a PR is ready for review.

---

## Pull Request Checklist

Before marking a PR ready for review, confirm:

- [ ] Branch named per convention (`p<N>/...` or `ci/...`)
- [ ] All existing tests pass
- [ ] New code has corresponding tests
- [ ] `shellcheck` and `ruff` produce no new warnings
- [ ] If the PR adds an install action, confirm with the maintainer that the uninstall counterpart is documented

---

## Scope

The project currently targets Arch-based distributions (CachyOS, Arch Linux,
EndeavourOS, Manjaro). Contributions for additional distro backends (`distros/`)
are welcome once the Arch implementation is stable — reach out in your
collaborator access request.

Contributions that expand scope beyond CAC/smart card authentication, or that
change the three-layer architecture without prior design discussion, will not
be accepted.

---

## License

By contributing, you agree that your contributions will be licensed under the
project's MIT license.
