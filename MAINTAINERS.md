# Maintainer habits (this repo + nested actions)

**Frequency:** only when you change default version numbers or bundled constraint packages — not every commit.

## Bump default version → run script → commit `constraints/*.txt`

If you skip this, CI still runs but the matching install logs **`::warning`** and uses **unhashed** `pip install`.

| Default you change | Where it lives | Script (run from that repo) | Constraint output |
|-------------------|----------------|----------------------------|-------------------|
| **`ruff_version`** | [`.github/workflows/ci.yml`](.github/workflows/ci.yml) + [`.github/actions/ruff/action.yml`](.github/actions/ruff/action.yml) | **`scripts/refresh-pip-constraints.sh`** | [`.github/actions/ruff/constraints/ruff-*`](.github/actions/ruff/constraints/) |
| **`pytest_version`** | `ci.yml` + [`.github/actions/pytest/action.yml`](.github/actions/pytest/action.yml) | same | [`.github/actions/pytest/constraints/pytest-*`](.github/actions/pytest/constraints/) |
| **`pip_tools_version`** (default **7.5.3**) | `ci.yml` | same | [`.github/actions/install-pip-tools-hashed/constraints.txt`](.github/actions/install-pip-tools-hashed/constraints.txt) |
| **PyYAML** in **install-pyyaml-hashed** | [`.github/actions/install-pyyaml-hashed/`](.github/actions/install-pyyaml-hashed/) | same | [`.github/actions/install-pyyaml-hashed/constraints.txt`](.github/actions/install-pyyaml-hashed/constraints.txt) |
| **`bandit_version`** (nested action) | **`thadiust/sast-bandit`** — `action.yml` | **`scripts/refresh-pip-constraints.sh`** (optional version arg) | `constraints/bandit-sarif-*.txt` |
| **`pip_audit_version`** (nested action) | **`thadiust/pip-audit-scan-action`** — `action.yml` (this workspace: **`scan-pip-audit/`**) | **`scripts/refresh-pip-constraints.sh`** | `constraints/pip-audit-*.txt` |

**Requires:** Python **3.11** and **pip-tools** (the scripts create a venv and install pip-tools).

After updating nested actions, **`workflow-python`** `ci.yml` already references **`@main`** for those repos — no extra step unless you cut semver tags elsewhere.

## Keep integration CI on

- **[`dogfood-ci.yml`](.github/workflows/dogfood-ci.yml)** — catches broken **`ci.yml`** wiring, DAG, and composites without waiting on **`sample-python-app`**.
- **[`scheduled-security-scan.yml`](.github/workflows/scheduled-security-scan.yml)** — weekly sanity check; ensure **Actions → General → Scheduled workflows** allows schedules if GitHub prompts.

## Dependabot

Merge **GitHub Actions** bumps (**`actions/checkout`**, **`setup-python`**, **`codeql-action`**, etc.) when convenient — reduces surprise deprecations; not urgent on every PR.

## CHANGELOG / releases

Update **[`CHANGELOG.md`](CHANGELOG.md)** (and tags / release notes) when you care about a clear **“what changed”** story for consumers. Optional for tiny solo-only edits if that’s your preference.
