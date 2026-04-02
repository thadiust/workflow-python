# workflow-python

Reusable GitHub Actions workflow for Python dependency security scanning. App repositories call [`.github/workflows/ci.yml`](.github/workflows/ci.yml), which runs the [`pip-audit`](https://github.com/pypa/pip-audit) scan via [`thadiust/pip-audit-scan-action`](https://github.com/thadiust/pip-audit-scan-action).

## Inputs

All inputs are optional; defaults assume `requirements.txt` at the repository root.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `working_directory` | string | `.` | Directory containing the Python project (relative to repo root). |
| `requirements_file` | string | `requirements.txt` | Path relative to `working_directory`. |
| `python_version` | string | `3.11` | Python version for the scan job. |
| `fail_on_vuln` | boolean | `true` | If `true`, the job fails when vulnerabilities are found. |

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
```

You can also run [`.github/workflows/ci.yml`](.github/workflows/ci.yml) manually via **workflow_dispatch** from the Actions tab of this repo. For stable behavior, pin `@main` to a commit SHA or tag instead of a branch.
