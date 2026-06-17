# Pytest composite action

Local composite used by the reusable workflow [`ci.yml`](../../workflows/ci.yml) in [`thadiust/workflow-python`](https://github.com/thadiust/workflow-python).

**Referencing this action:** Use `uses: thadiust/workflow-python/.github/actions/pytest@<ref>`, **not** `uses: ./.github/...` (for reusable workflows, `./` resolves against the **caller** repository). **Consumer repos** should pin the **same semver tag** on `ci.yml` and this action (e.g. both **`@v1.0.8`**). The **`workflow-python`** repo may use **`@main`** on branch `main` for development; do not point consumer apps at **`@main`** unless you want floating behavior.

## What it runs

1. Sets up Python via `actions/setup-python`
2. Installs dependencies from `requirements_file` with **`pip install -r`** (not **`--require-hashes`**) unless that file itself contains **PEP 503** hashes — a typical **`pip-compile`** lock **without** **`--generate-hashes`** is **version-pinned** but **not** hash-verified at install.
3. Installs **`pytest`** with **`pip --require-hashes`** when **`constraints/pytest-<version>.txt`** exists for **`pytest_version`** (default **9.0.3**); otherwise **`pip install pytest==…`** with a warning. Regenerate constraints via **`scripts/refresh-pip-constraints.sh`** in **`workflow-python`** after bumps.
4. Runs `python -m pytest` with `pytest_args`

On failure, it writes a short **Job Summary** with copy-paste commands.

## Inputs

| Input | Default | Notes |
|------|---------|------|
| `python_version` | `3.11` | For `actions/setup-python`. |
| `working_directory` | `.` | Repo-relative directory to run from. |
| `requirements_file` | `requirements.txt` | Relative to `working_directory`. |
| `extra_install_args` | *(empty)* | Extra args passed to `pip install -r ...` (space-separated). |
| `app_requirements_require_hashes` | `false` | If **`true`**, app **`pip install -r`** uses **`--require-hashes`** (requirements file must include PEP 503 hashes). |
| `pytest_version` | `9.0.3` | Exact pytest version string. |
| `pytest_args` | *(empty)* | Space-separated args; **empty** = auto (`tests/` or `test/` or discovery). |
