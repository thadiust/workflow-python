# Ruff composite action

Local composite used by the [`ruff-lint`](../../workflows/ci.yml) job. Callers use the reusable workflow [`ci.yml`](../../workflows/ci.yml) from [`thadiust/workflow-python`](https://github.com/thadiust/workflow-python).

**Referencing this action:** The workflow must use `uses: thadiust/workflow-python/.github/actions/ruff@<ref>`, **not** `uses: ./.github/actions/ruff`. For reusable workflows, `./` is resolved against the **caller** repository (e.g. your app), so a local path would not find this action. **Consumer repos** should pin the **same semver tag** on `ci.yml` and this action (e.g. both **`@v1.0.8`**). The **`workflow-python`** repo may use **`@main`** on branch `main` to exercise the latest composites during development; do not point consumer apps at **`@main`** unless you intentionally want floating behavior.

## What it runs

1. **`ruff check`** — once, with **`--output-format github`** (PR/Actions annotations) and **`--force-exclude`** (honors excludes when paths are explicit, similar to pre-commit hooks).
2. Optionally **`ruff format --check`** — same paths and config, also with **`--force-exclude`**.

Ruff is installed with **`pip --require-hashes`** when **`constraints/ruff-<version>.txt`** exists for the pinned **`ruff_version`** (default **0.15.9**); otherwise **`pip install --no-deps ruff==…`** with a workflow warning. Regenerate constraints via **`scripts/refresh-pip-constraints.sh`** in the **`workflow-python`** repo after version bumps.

On **failure**, the step writes a short **Job Summary** (GitHub **Summary** tab) with copy-paste **Ruff** commands matching CI, prints **`ruff format --diff`** in the log when format is the problem, and prints a **brief** stderr pointer to the Summary. **Venv**, **PEP 668**, and shell quirks belong in the **consumer repo README**, not in CI noise.

## Inputs

| Input | Default | Notes |
|-------|---------|--------|
| `python_version` | `3.11` | For `actions/setup-python`. |
| `ruff_version` | `0.15.9` | Exact version string. |
| `working_directory` | `.` | Repo-relative directory for all paths. |
| `paths` | `.` | Space-separated paths relative to `working_directory`. No `..` segments or absolute paths. |
| `config` | *(empty)* | Optional `--config` path relative to `working_directory`. |
| `run_format_check` | `true` | Set `false` to skip `ruff format --check`. |
| `fail_on_findings` | `true` | If `true`, exit **1** when check or format reports work; if `false`, those cases exit **0**. |

## Outputs

| Output | Meaning |
|--------|---------|
| `format_ok` | `true` / `false` |
| `scan_status` | `clean`, `findings_found`, or `scanner_error` |

Exit semantics: Ruff **0** = clean, **1** = findings, **2** = tool/CLI error. The composite maps **2** to **`scanner_error`** and fails the step.

## Project configuration

Consumer repos should add **`pyproject.toml`** and/or **`ruff.toml`** (and line up with local **pre-commit** if you use it later). This action does not create config for you.

For the full pipeline (job order, Gitleaks, Bandit, pip-audit), see the [workflow-python README](../../../README.md).
