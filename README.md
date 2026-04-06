# workflow-python

Reusable GitHub Actions workflow for Python security checks. App repositories call [`.github/workflows/ci.yml`](.github/workflows/ci.yml), which runs:

1. **[Ruff](https://docs.astral.sh/ruff/)** via the composite at [`thadiust/workflow-python/.github/actions/ruff`](.github/actions/ruff/README.md) (referenced by ref in [`ci.yml`](.github/workflows/ci.yml), not `./…`, so it works when the reusable workflow runs in **caller** repos). `ruff check` (GitHub annotations) and optional `ruff format --check`, pinned version, **`--force-exclude`**. Toggle with `run_ruff` and related inputs.
2. **[Gitleaks](https://github.com/gitleaks/gitleaks)** via [`thadiust/secrets-gitleaks`](https://github.com/thadiust/secrets-gitleaks) (secrets; **full git history** — checkout uses `fetch-depth: 0`). If you **delete** a leaked file in a new commit but the job **still fails**, Gitleaks is matching an **older commit**; you need **history cleanup** (squash / `git filter-repo`) or a **baseline**, not only a delete commit. See [**Removed the file, but CI still fails?**](https://github.com/thadiust/secrets-gitleaks/blob/main/README.md#removed-the-file-but-ci-still-fails) in the action README.
3. In parallel after that: **[Bandit](https://github.com/pycqa/bandit)** ([`thadiust/sast-bandit`](https://github.com/thadiust/sast-bandit)) for SAST (**issues**) and **[pip-audit](https://github.com/pypa/pip-audit)** ([`thadiust/pip-audit-scan-action`](https://github.com/thadiust/pip-audit-scan-action)) for dependency **vulnerabilities**

**Ruff** runs first when enabled. **Gitleaks** runs after Ruff succeeds or if Ruff is skipped. **Bandit** and **pip-audit** run **in parallel** after that; each **`needs`** **`ruff-lint`** and **`gitleaks-scan`**, and only runs when Ruff is **success or skipped** *and* Gitleaks is **success or skipped** — so a **failed Ruff** does not still run Bandit/pip-audit (Gitleaks can be “skipped” in that case, which previously looked like `run_gitleaks: false`). If Gitleaks fails, both are skipped. Toggle jobs with `run_ruff`, `run_gitleaks`, `run_bandit`, and `run_pip_audit_scan`. If **every** job is disabled, the workflow has no jobs and GitHub will reject the run — leave at least one enabled.

This layout **fails fast on lint**, then **secrets**, while **SAST (Bandit)** and **SCA (pip-audit)** stay **independent** after secrets.

### Terminology

Across these jobs, a **finding** is anything that can fail the pipeline when the matching toggle and fail mode are on:

| Job | Finding type | Typical output |
|-----|----------------|----------------|
| Ruff | **Lint / format** | `scan_status`, `format_ok` |
| Gitleaks | **Secrets** | `secret_count` |
| Bandit | **Issues** (SAST) | `issue_count` |
| pip-audit | **Vulnerabilities** (dependencies) | `vuln_count` |

## Security and cost

- **Token scope:** The workflow sets **`permissions: contents: read`** so the default `GITHUB_TOKEN` is not granted write access it does not need.
- **Checkout:** Jobs use **`persist-credentials: false`** so the credential helper is not left configured for later steps. Gitleaks uses **`fetch-depth: 0`** (full history); Bandit and pip-audit use **`fetch-depth: 1`** (current commit only) to avoid cloning full history on two extra runners.
- **Concurrency:** This workflow defines a **`concurrency`** group (per repository and ref) with **`cancel-in-progress: true`** so superseded runs are dropped when the same branch is pushed again. If your **caller** workflow defines its own `concurrency`, GitHub applies the caller’s rules for the whole run; avoid defining two competing groups for the same jobs.
- **Parallel jobs vs minutes:** Ruff and Gitleaks run **one after the other** (one runner at a time for those stages). After Gitleaks, **Bandit** and **pip-audit** can run **at the same time** (two runners). **Billed minutes** sum across all jobs. Disable jobs you do not need via inputs to save time.
- **Timeouts:** Ruff uses **`timeout-minutes: 15`**; other jobs use **`timeout-minutes: 30`** so a hung scanner does not burn the runner default (6 hours).
- **Supply chain:** Callers should **pin** `uses: ...@sha` for this workflow and for each composite action instead of `@main` when you want immutable behavior.

## Inputs

All inputs are optional; defaults assume `requirements.txt` at the repository root.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `working_directory` | string | `.` | Directory containing the Python project (relative to repo root). |
| `requirements_file` | string | `requirements.txt` | Path relative to `working_directory`. |
| `python_version` | string | `3.11` | Python version for Ruff, Bandit, and pip-audit jobs. |
| `fail_on_vuln` | boolean | `true` | If `true`, the pip-audit job fails when vulnerabilities are found. |
| `run_ruff` | boolean | `true` | If `false`, the Ruff job is skipped. |
| `ruff_version` | string | `0.15.9` | Exact Ruff version installed in the lint job. |
| `ruff_paths` | string | `.` | Space-separated paths relative to `working_directory` for `ruff check` / `ruff format`. |
| `ruff_config` | string | *(empty)* | Optional Ruff config path relative to `working_directory`. |
| `run_ruff_format` | boolean | `true` | If `false`, skip `ruff format --check`. |
| `ruff_fail_on_findings` | boolean | `true` | If `true`, the Ruff job fails when check or format reports work to do. |
| `run_gitleaks` | boolean | `true` | If `false`, the Gitleaks job is skipped. |
| `run_pip_audit_scan` | boolean | `true` | If `false`, the pip-audit job is skipped. |
| `run_bandit` | boolean | `true` | If `false`, the Bandit job is skipped. |
| `bandit_config` | string | *(empty)* | Optional path to a Bandit config file relative to `working_directory` (for example `bandit.yaml`). |
| `bandit_minimum_severity` | string | `all` | Bandit severity floor: `all`, `low`, `medium`, or `high`. Issues below this level are omitted from the report and do not fail the job. `medium` blocks on medium and high only. |

## Example: call from another repository

```yaml
name: App CI

permissions:
  contents: read

on:
  pull_request:
    branches: [main]

jobs:
  security:
    uses: thadiust/workflow-python/.github/workflows/ci.yml@main
    with:
      working_directory: "."
      requirements_file: "requirements.txt"
      python_version: "3.11"
      fail_on_vuln: true
      run_gitleaks: true
      run_pip_audit_scan: true
      run_bandit: true
```

You can also run [`.github/workflows/ci.yml`](.github/workflows/ci.yml) manually via **workflow_dispatch** from the Actions tab of this repo. For stable behavior, pin `@main` to a commit SHA or tag instead of a branch.
