# workflow-python

Reusable GitHub Actions workflow for Python security checks. App repositories call [`.github/workflows/ci.yml`](.github/workflows/ci.yml), which can run a [`pip-audit`](https://github.com/pypa/pip-audit) dependency scan ([`thadiust/pip-audit-scan-action`](https://github.com/thadiust/pip-audit-scan-action)) and a Bandit SAST job ([`thadiust/sast-bandit`](https://github.com/thadiust/sast-bandit)). Toggle each job with `run_pip_audit_scan` and `run_bandit` so you can test or debug one scan without the other. If both are `false`, the workflow has no jobs and GitHub will reject the run—leave at least one enabled.

## Inputs

All inputs are optional; defaults assume `requirements.txt` at the repository root.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `working_directory` | string | `.` | Directory containing the Python project (relative to repo root). |
| `requirements_file` | string | `requirements.txt` | Path relative to `working_directory`. |
| `python_version` | string | `3.11` | Python version for the scan job. |
| `fail_on_vuln` | boolean | `true` | If `true`, the pip-audit job fails when vulnerabilities are found. |
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
      run_pip_audit_scan: true
      run_bandit: true
```

You can also run [`.github/workflows/ci.yml`](.github/workflows/ci.yml) manually via **workflow_dispatch** from the Actions tab of this repo. For stable behavior, pin `@main` to a commit SHA or tag instead of a branch.
