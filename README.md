# workflow-python

Reusable GitHub Actions workflow for Python security checks. App repositories call [`.github/workflows/ci.yml`](.github/workflows/ci.yml), which runs:

1. **[Gitleaks](https://github.com/gitleaks/gitleaks)** via [`thadiust/secrets-gitleaks`](https://github.com/thadiust/secrets-gitleaks) (secrets; **full git history** — checkout uses `fetch-depth: 0`)
2. In parallel after that: **[Bandit](https://github.com/pycqa/bandit)** ([`thadiust/sast-bandit`](https://github.com/thadiust/sast-bandit)) for SAST and **[pip-audit](https://github.com/pypa/pip-audit)** ([`thadiust/pip-audit-scan-action`](https://github.com/thadiust/pip-audit-scan-action)) for dependency vulnerabilities

**Gitleaks** runs first. **Bandit** and **pip-audit** run **in parallel** after Gitleaks finishes (each job only `needs: gitleaks-scan`), so neither SCA nor SAST blocks the other. If Gitleaks fails, both are skipped. Toggle each job with `run_gitleaks`, `run_bandit`, and `run_pip_audit_scan`. If all three are `false`, the workflow has no jobs and GitHub will reject the run — leave at least one enabled.

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
| `bandit_minimum_severity` | string | `all` | Bandit severity floor: `all`, `low`, `medium`, or `high`. Findings below this level are omitted from the report and do not fail the job. `medium` blocks on medium and high only. |

## Example: call from another repository

```yaml
name: App CI

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
