# Maintainer habits (this repo + nested actions)

**Severity scale:** **10** = treat as mandatory when the situation applies; **0** = ignore until you care. Intermediate numbers are relative priority, not hard rules.

**Frequency:** for constraint refresh, only when default version numbers or bundled pins change — not every commit.

---

## Severity 10 — Hash constraints when defaults move

When you change **default versions** in [`ci.yml`](.github/workflows/ci.yml) or composite [`action.yml`](.github/actions/) defaults, or the **PyYAML** version that [`scripts/refresh-pip-constraints.sh`](scripts/refresh-pip-constraints.sh) pins for **install-pyyaml-hashed**, run the matching **`scripts/refresh-pip-constraints.sh`** and commit the updated **`constraints/*.txt`** (or **`install-*-hashed/constraints.txt`**). If you skip this, CI still runs but you lose **`--require-hashes`** for that tool: **`::warning`** plus a plain **`pip install`**.

| Default you change | Where it lives | Script (run from that repo) | Constraint output |
|-------------------|----------------|----------------------------|-------------------|
| **`ruff_version`** | `ci.yml` + [`.github/actions/ruff/action.yml`](.github/actions/ruff/action.yml) | **`scripts/refresh-pip-constraints.sh`** | [`.github/actions/ruff/constraints/ruff-*`](.github/actions/ruff/constraints/) |
| **`pytest_version`** | `ci.yml` + [`.github/actions/pytest/action.yml`](.github/actions/pytest/action.yml) | same | [`.github/actions/pytest/constraints/pytest-*`](.github/actions/pytest/constraints/) |
| **`pip_tools_version`** (default **7.5.3**) | `ci.yml` | same | [`.github/actions/install-pip-tools-hashed/constraints.txt`](.github/actions/install-pip-tools-hashed/constraints.txt) |
| **PyYAML** in **install-pyyaml-hashed** | [`.github/actions/install-pyyaml-hashed/`](.github/actions/install-pyyaml-hashed/) | same | [`.github/actions/install-pyyaml-hashed/constraints.txt`](.github/actions/install-pyyaml-hashed/constraints.txt) |
| **`bandit_version`** (nested action) | **`thadiust/sast-bandit`** — `action.yml` | **`scripts/refresh-pip-constraints.sh`** (optional version arg) | `constraints/bandit-sarif-*.txt` |
| **`pip_audit_version`** (nested action) | **`thadiust/pip-audit-scan-action`** — `action.yml` (this workspace: **`scan-pip-audit/`**) | **`scripts/refresh-pip-constraints.sh`** | `constraints/pip-audit-*.txt` |

**Requires:** Python **3.11** and **pip-tools** (the scripts create a venv and install pip-tools).

**`thadiust/... @main`:** no change required when you only bump defaults here — consumers already track **`main`** unless you adopt tags later.

---

## Severity 7 — Dogfood blast radius (multi-repo)

[`dogfood-ci.yml`](.github/workflows/dogfood-ci.yml) runs on **push**/**PR** only when these paths change: `.github/workflows/ci.yml`, `.github/workflows/dogfood-ci.yml`, `.github/actions/**`, and `dogfood/**`.

Edits that live **only** in sibling repos (**`sast-bandit`**, **`pip-audit-scan-action`** / **`scan-pip-audit`**, **`trivy-scan`**, **`secrets-gitleaks`**) do **not** trigger **workflow-python** dogfood unless you also touch **workflow-python** or you rely on **those repos’ own CI**. When your local workspace and published repos diverge, **know what integration actually ran**.

---

## Severity 6 — First-party `@main` risk

**`ci.yml`** references first-party actions at **`@main`**. A bad push to e.g. **sast-bandit** `main` can break **`ci.yml`** consumers immediately. For a solo setup that is often acceptable; mitigations later are **semver tags** or a staging branch — not required now.

---

## Severity 5 — Scheduled workflows (repo setting)

[`scheduled-security-scan.yml`](.github/workflows/scheduled-security-scan.yml) runs on a **weekly** cron (and **`workflow_dispatch`**). If GitHub has **disabled scheduled workflows** for the repo until you allow them, you get **no weekly run** until you enable them under **Settings → Actions → General → Workflow permissions** (wording varies slightly by UI).

**Leave dogfood + scheduled on** when you want **`ci.yml`** regressions without waiting on **`sample-python-app`**. Scheduled has **no path filter** — it always targets the current `main` graph when the schedule fires.

---

## Severity 4 — Dependabot for Actions

Merge Dependabot PRs for **`actions/checkout`**, **`actions/setup-python`**, **`github/codeql-action`**, and similar on a rhythm you like — reduces surprise breakages; **not** urgent on every alert.

---

## CHANGELOG / releases

Update **[`CHANGELOG.md`](CHANGELOG.md)** (and tags / release notes) when you care about a clear **“what changed”** story. Optional for tiny solo-only edits if you prefer.
