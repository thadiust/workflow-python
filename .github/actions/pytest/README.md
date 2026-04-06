# Pytest composite action

Local composite used by the reusable workflow [`ci.yml`](../../workflows/ci.yml) in [`thadiust/workflow-python`](https://github.com/thadiust/workflow-python).

**Referencing this action:** Use `uses: thadiust/workflow-python/.github/actions/pytest@<ref>`, not a `./.github/...` path (local paths resolve in the *caller* repo).

## What it runs

1. Sets up Python via `actions/setup-python`
2. Installs dependencies from `requirements_file`
3. Ensures `pytest` is installed
4. Runs `python -m pytest` with `pytest_args`

On failure, it writes a short **Job Summary** with copy-paste commands.

## Inputs

| Input | Default | Notes |
|------|---------|------|
| `python_version` | `3.11` | For `actions/setup-python`. |
| `working_directory` | `.` | Repo-relative directory to run from. |
| `requirements_file` | `requirements.txt` | Relative to `working_directory`. |
| `extra_install_args` | *(empty)* | Extra args passed to `pip install -r ...` (space-separated). |
| `pytest_version` | `9.0.2` | Exact pytest version string. |
| `pytest_args` | *(empty)* | Space-separated args; **empty** = auto (`tests/` or `test/` or discovery). |
