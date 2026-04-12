# Maintainer habits (this repo + nested actions)

**Severity scale:** **10** = treat as mandatory when the situation applies; **0** = ignore until you care. Intermediate numbers are relative priority, not hard rules.

**Frequency:** for constraint refresh, only when default version numbers or bundled pins change — not every commit.

**Pre-commit:** **[`.pre-commit-config.yaml`](.pre-commit-config.yaml)** — bump **`astral-sh/ruff-pre-commit`** / **Gitleaks** **`rev:`** when you upgrade Ruff or when **`ci.yml`** **`gitleaks_version`** changes; run **`pre-commit autoupdate`** for **`pre-commit/pre-commit-hooks`** (and review the diff). **`ci.yml`** **`pre-commit-check`** and **[`.github/workflows/pre-commit.yml`](.github/workflows/pre-commit.yml)** both run **`pre-commit run --all-files`** (**no** separate Ruff job in **`ci.yml`**).

---

## Severity 10 — Hash constraints when defaults move

When you bump a default for **ruff**, **pytest**, **bandit**, **pip-audit**, **pip-tools**, or **PyYAML** (in [`ci.yml`](.github/workflows/ci.yml), composite [`action.yml`](.github/actions/) files, or the pin logic in [`scripts/refresh-pip-constraints.sh`](scripts/refresh-pip-constraints.sh)), run the matching **`scripts/refresh-pip-constraints.sh`** and commit the new constraint files — or you **silently** drop **`--require-hashes`** for that tool (**`::warning`** + plain **`pip install`**). CI still runs; installs are just unhashed for the mismatch.

| Default you change | Where it lives | Script (run from that repo) | Constraint output |
|-------------------|----------------|----------------------------|-------------------|
| **Ruff** | [`.pre-commit-config.yaml`](.pre-commit-config.yaml) (`ruff-pre-commit`) + optional [`.github/actions/ruff`](.github/actions/ruff/README.md) | **`pre-commit autoupdate`** / hook **`rev:`**; for composite, **`scripts/refresh-pip-constraints.sh`** | [`.github/actions/ruff/constraints/ruff-*`](.github/actions/ruff/constraints/) |
| **`pytest_version`** | `ci.yml` + [`.github/actions/pytest/action.yml`](.github/actions/pytest/action.yml) | same | [`.github/actions/pytest/constraints/pytest-*`](.github/actions/pytest/constraints/) |
| **`pip_tools_version`** (default **7.5.3**) | `ci.yml` | same | [`.github/actions/install-pip-tools-hashed/constraints.txt`](.github/actions/install-pip-tools-hashed/constraints.txt) |
| **PyYAML** in **install-pyyaml-hashed** | [`.github/actions/install-pyyaml-hashed/`](.github/actions/install-pyyaml-hashed/) | same | [`.github/actions/install-pyyaml-hashed/constraints.txt`](.github/actions/install-pyyaml-hashed/constraints.txt) |
| **`bandit_version`** (nested action) | **`thadiust/sast-bandit`** — `action.yml` | **`scripts/refresh-pip-constraints.sh`** (optional version arg) | `constraints/bandit-sarif-*.txt` |
| **`pip_audit_version`** (nested action) | **`thadiust/pip-audit-scan-action`** — `action.yml` (this workspace: **`scan-pip-audit/`**) | **`scripts/refresh-pip-constraints.sh`** | `constraints/pip-audit-*.txt` |

**Layout:** Hashed pip constraint **trees** named **`constraints/`** exist for **ruff**, **pytest**, **bandit**, and **pip-audit**. **pip-tools** and **PyYAML** use **`install-*-hashed/constraints.txt`** at the composite root — **not** a **`constraints/`** subfolder (hence four **`constraints/`** trees in the repo, not six).

**`pip_tools_version`:** **[`install-pip-tools-hashed`](.github/actions/install-pip-tools-hashed/action.yml)** applies **`--require-hashes`** only when the version is **exactly `7.5.3`**. Any other **`pip_tools_version`** uses **plain** **`pip install pip-tools==…`** until you add a matching **`constraints.txt`** and wire the composite — see **[`CI_RISK_REGISTER.md`](CI_RISK_REGISTER.md)**. Enterprise: **`pip_tools_require_hashed_install: true`** on **`ci.yml`** (with **`enforce_pip_tools_lockfile`**) **fails** if version ≠ **7.5.3** until constraints exist for that version.

**Requires:** Python **3.11** and **pip-tools** (the scripts create a venv and install pip-tools).

Bumping defaults **here** does not require editing **`uses: thadiust/... @main`** lines; see **severity 7** for what **`@main`** still implies.

---

## Severity 7 — Multi-repo coupling (`@main` on nested actions)

**`ci.yml`** references first-party actions at **`@main`**. A bad push to **sast-bandit**, **pip-audit-scan-action**, or similar can break **`ci.yml`** callers **immediately**. For solo work that is often **acceptable**; treat this as **awareness**, not a required change (tags / staging come later if you want them).

---

## Severity 6 — Dogfood only on workflow-python paths

[`dogfood-ci.yml`](.github/workflows/dogfood-ci.yml) runs on **push**/**PR** only when these paths change: `.github/workflows/ci.yml`, `.github/workflows/dogfood-ci.yml`, `.github/actions/**`, and `dogfood/**`.

Changes **only** in other published repos do **not** re-run the full **`ci.yml`** integration **from workflow-python** unless you trigger it another way (**`workflow_dispatch`**, a touch under those paths, or that repo’s **own** CI). When the monorepo and GitHub repos diverge, **know what actually ran**.

---

## Severity 5 — Scheduled workflows (repo setting)

[`scheduled-security-scan.yml`](.github/workflows/scheduled-security-scan.yml) runs on a **weekly** cron (and **`workflow_dispatch`**). Scheduled workflows must be **allowed** in repo **Actions** settings or **cron will not run**. **Leave dogfood + scheduled on** when you want **`ci.yml`** regressions without waiting on **`sample-python-app`**. Scheduled has **no path filter** — it targets the current **`main`** graph when it fires.

---

## Severity 4 — Dependabot for third-party Actions

Merge Dependabot PRs for **`actions/checkout`**, **`actions/setup-python`**, **`github/codeql-action`**, and similar **when convenient** — avoids surprise breakages; **not** urgent on every alert.

---

## Severity 2 — Optional memory aids

**[`CHANGELOG.md`](CHANGELOG.md)**, this table, and other one-line bump checklists — **optional**; use them when you want a paper trail.

---

## Severity 0 — Ignore until you care

**Org / owner rename** (e.g. **`thadiust`**) if you are **not** doing it. **Roadmap** tooling (**Grype**, **SBOM**, **Sonar**, …) until you explicitly want it.

---

**Bottom line:** After a re-check, if **defaults** and **committed hashes** stay aligned for pip-installed tools, your standing **10** is still: **version bump → `refresh-pip-constraints.sh` → commit in the right repo(s)**.
