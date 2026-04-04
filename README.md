# workflow-python

Reusable GitHub Actions workflow for Python security checks. App repositories call [`.github/workflows/ci.yml`](.github/workflows/ci.yml), which runs:

1. **[Gitleaks](https://github.com/gitleaks/gitleaks)** via [`thadiust/secrets-gitleaks`](https://github.com/thadiust/secrets-gitleaks) (secrets; **full git history** — checkout uses `fetch-depth: 0`). If you **delete** a leaked file in a new commit but the job **still fails**, Gitleaks is matching an **older commit**; you need **history cleanup** (squash / `git filter-repo`) or a **baseline**, not only a delete commit. See [**Removed the file, but CI still fails?**](https://github.com/thadiust/secrets-gitleaks/blob/main/README.md#removed-the-file-but-ci-still-fails) in the action README.
2. In parallel after that: **[Bandit](https://github.com/pycqa/bandit)** ([`thadiust/sast-bandit`](https://github.com/thadiust/sast-bandit)) for SAST (**issues**) and **[pip-audit](https://github.com/pypa/pip-audit)** ([`thadiust/pip-audit-scan-action`](https://github.com/thadiust/pip-audit-scan-action)) for dependency **vulnerabilities**

**Gitleaks** runs first. **Bandit** and **pip-audit** run **in parallel** after Gitleaks finishes (each job only `needs: gitleaks-scan`), so neither SCA nor SAST blocks the other. If Gitleaks fails, both are skipped. Toggle each job with `run_gitleaks`, `run_bandit`, and `run_pip_audit_scan`. If all three are `false`, the workflow has no jobs and GitHub will reject the run — leave at least one enabled.

This layout **fails fast on secrets** while **SAST (Bandit)** and **SCA (pip-audit)** run **independently**, so you get maximum visibility from both without either gate blocking the other.

### Terminology

Across these jobs, a **finding** is anything that can fail the pipeline when the matching toggle and fail mode are on:

| Job | Finding type | Typical output |
|-----|----------------|----------------|
| Gitleaks | **Secrets** | `secret_count` |
| Bandit | **Issues** (SAST) | `issue_count` |
| pip-audit | **Vulnerabilities** (dependencies) | `vuln_count` |

## Security and cost

- **Token scope:** The workflow sets **`permissions: contents: read`** so the default `GITHUB_TOKEN` is not granted write access it does not need.
- **Checkout:** Jobs use **`persist-credentials: false`** so the credential helper is not left configured for later steps. Gitleaks uses **`fetch-depth: 0`** (full history); Bandit and pip-audit use **`fetch-depth: 1`** (current commit only) to avoid cloning full history on two extra runners.
- **Concurrency:** This workflow defines a **`concurrency`** group (per repository and ref) with **`cancel-in-progress: true`** so superseded runs are dropped when the same branch is pushed again. If your **caller** workflow defines its own `concurrency`, GitHub applies the caller’s rules for the whole run; avoid defining two competing groups for the same jobs.
- **Parallel jobs vs minutes:** With all three scans enabled you use **up to three runners** per run (one job each). That improves wall-clock time and keeps SAST and SCA independent, but **billed minutes** sum across jobs. To optimize cost, disable scans you do not need via inputs or collapse into a single job in a fork (not supported in this reusable workflow as shipped).
- **Timeouts:** Each job has **`timeout-minutes: 30`** so a hung scanner does not burn the runner default (6 hours).
- **Supply chain:** Callers should **pin** `uses: ...@sha` for this workflow and for each composite action instead of `@main` when you want immutable behavior.

## Inputs

All inputs are optional; defaults assume `requirements.txt` at the repository root.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `working_directory` | string | `.` | Directory containing the Python project (relative to repo root). |
| `requirements_file` | string | `requirements.txt` | Path relative to `working_directory`. |
| `python_version` | string | `3.11` | Python version for Bandit and pip-audit jobs. |
| `fail_on_vuln` | boolean | `true` | If `true`, the pip-audit job fails when vulnerabilities are found. |
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
