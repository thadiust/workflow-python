# workflow-python

**Branch `main` vs semver tags:** If you use this repo inside the [`security-pipeline`](../README.md) workspace, read **Branch `main` vs release tags** there first. In short: **`main`** floats **Ruff** and **pytest** composites (`@main`); **consumers** should call **`ci.yml@v…`** so Ruff/pytest and **`thadiust/*`** actions match a tagged snapshot.

**Lint in this repo:** [`.github/workflows/actionlint.yml`](.github/workflows/actionlint.yml) runs **actionlint** on **`.github/workflows/`** (including reusable **`ci.yml`**) and **PyYAML**-parses each file under **`.github/actions/`** named `action.yml` or `action.yaml`. That catches workflow typos before tags; full composite semantics are still GitHub’s parser at runtime.

Reusable GitHub Actions workflow for Python security checks. App repositories call [`.github/workflows/ci.yml`](.github/workflows/ci.yml), which runs:

1. **[Ruff](https://docs.astral.sh/ruff/)** via the composite at [`.github/actions/ruff`](.github/actions/ruff/README.md). On branch **`main`**, [`ci.yml`](.github/workflows/ci.yml) references **`thadiust/workflow-python/.github/actions/ruff@main`** (not `./…`: with a **reusable workflow** called from another repo, **local `./` paths resolve on the caller’s checkout**, so composites must use the **`owner/repo`** form). **Semver tags** (e.g. **`v1.0.5`**) pin **`…/ruff@v1.0.5`** alongside **`ci.yml@v1.0.5`**. `ruff check` (GitHub annotations) and optional `ruff format --check`, pinned version, **`--force-exclude`**. Toggle with `run_ruff` and related inputs.
2. **[pytest](https://pytest.org/)** via [`.github/actions/pytest`](.github/actions/pytest/README.md) (**`@main`** on branch **main**; **`@v1.0.x`** on matching release tags), **in parallel** with Ruff when both are enabled (`run_pytest`). Installs deps from `pytest_requirements_file` and runs `python -m pytest` with `pytest_args`; pytest itself is pinned to `pytest_version`.
3. **[Gitleaks](https://github.com/gitleaks/gitleaks)** via [`thadiust/secrets-gitleaks`](https://github.com/thadiust/secrets-gitleaks) (**`uses: …/secrets-gitleaks@v1.0.2`** on branch **main** — tag releases in that repo to bump). Secrets; **full git history** — checkout uses `fetch-depth: 0`. **`gitleaks-scan`** **`needs`** **`ruff-lint`** and **`pytest-test`**. See [**Removed the file, but CI still fails?**](https://github.com/thadiust/secrets-gitleaks/blob/main/README.md#removed-the-file-but-ci-still-fails) in the action README.
4. After Gitleaks: **[Bandit](https://github.com/pycqa/bandit)** via [`thadiust/sast-bandit`](https://github.com/thadiust/sast-bandit) (**`…/sast-bandit@v1.0.1`**) and **[pip-audit](https://github.com/pypa/pip-audit)** via [`thadiust/pip-audit-scan-action`](https://github.com/thadiust/pip-audit-scan-action) (**`…/pip-audit-scan-action@v1.0.0`**) — dependency **vulnerabilities** (in parallel with each other).

**Bandit** and **pip-audit** each **`needs`** **`ruff-lint`**, **`gitleaks-scan`**, and **`pytest-test`**. If **pytest fails**, **Gitleaks**, **Bandit**, and **pip-audit** **do not run** (no secrets/SAST/SCA on that run — fix tests or use toggles if you need a different policy). If **Gitleaks fails**, Bandit and pip-audit are skipped. `run_pytest: false` skips the pytest job so downstream jobs still run when other gates pass. Toggle jobs with `run_ruff`, `run_pytest`, `run_gitleaks`, `run_bandit`, and `run_pip_audit_scan`. If **every** job is disabled, the workflow has no jobs and GitHub will reject the run — leave at least one enabled.

This layout **fails fast on lint and tests**, then **secrets**, then **SAST (Bandit)** and **SCA (pip-audit)**; Bandit and pip-audit stay **independent** of each other.

### Pip, lockfiles, and SCA (why `requirements.in` + `requirements.txt`)

**pip-audit** reports vulnerabilities for the **dependency graph implied by the file** you pass to `-r`. A hand-edited `requirements.txt` with only top-level pins still leaves **transitive versions** to the resolver at install time unless you record them. **pip-tools** separates concerns:

- **`requirements.in`** — what you intend (ranges or top-level pins).
- **`requirements.txt`** — **fully pinned** output from **`pip-compile`** (transitives included).

Turn **`enforce_pip_tools_lockfile: true`** so CI runs **`pip-compile … -o requirements.txt`** and **`git diff --exit-code`** on the lock: if someone edits **`.in`** without regenerating the lock, the job fails. Point **`pytest_requirements_file`** at the **same lock** as **`requirements_file`** so tests and SCA see one graph.

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
- **Tests before security scans (deliberate):** **Gitleaks**, **Bandit**, and **pip-audit** run only after **Ruff** and **pytest** succeed (or are skipped via toggles). If **pytest fails**, those security jobs **do not run** — fewer CI minutes and a clear “fix tests first” signal. Some orgs prefer secrets/SCA even on red tests; this workflow does **not** do that unless you fork and change **`needs:`** / **`if:`**.
- **Parallel jobs vs minutes:** **`runner-info`** logs documented **`runner.*`** fields (`os`, `arch`, `environment`, `name`) once — **`runner.environment`** shows **`github-hosted`** vs **`self-hosted`**. **Ruff** and **pytest** run **in parallel** (two more runners when both are enabled). **Gitleaks** starts only after **both** Ruff and pytest finish (**success or skipped**). After Gitleaks, **Bandit** and **pip-audit** run **at the same time** (two more runners). **Billed minutes** sum across all jobs. Disable jobs you do not need via inputs to save time.
- **Timeouts:** Ruff uses **`timeout-minutes: 15`**; other jobs use **`timeout-minutes: 30`** so a hung scanner does not burn the runner default (6 hours).
- **Supply chain:** Callers should reference this workflow with **`@main`** or a **semver tag** (e.g. **`@v1.0.5`**). This project does not require pinning to commit SHAs. **Note:** Each job’s **`uses:`** resolves independently. On **semver tags**, **Ruff** and **pytest** use the **same tag** as **`ci.yml`**. On branch **`main`**, **Ruff** and **pytest** use **`@main`** so CI exercises the latest local composites. **`secrets-gitleaks`** is pinned at **`@v1.0.2`**; **`sast-bandit`** at **`@v1.0.1`**; **`pip-audit-scan-action`** at **`@v1.0.0`** (see [`ci.yml`](.github/workflows/ci.yml)). **`upload_code_scanning`** (default **`true`**) uploads **Gitleaks** and **Bandit** SARIF via **`github/codeql-action/upload-sarif`** — caller workflows need **`permissions: security-events: write`** on the job that **`uses`** this workflow (see example). Upload steps use **`continue-on-error: true`** so missing **GitHub Advanced Security** does not fail the pipeline.

### Releasing a new semver tag (`v1.x.y`)

1. In [`.github/workflows/ci.yml`](.github/workflows/ci.yml), set **`thadiust/workflow-python/.github/actions/ruff@v1.x.y`** and **`…/pytest@v1.x.y`** to match the tag you are about to create (so **`ci.yml@v1.x.y`** and the composites resolve to the same commit).
2. Commit, create the annotated tag **`v1.x.y`**, push **`main`** and **`git push origin v1.x.y`**.
3. On **`main`**, follow up with a commit that sets **Ruff** and **pytest** back to **`@main`** so day-to-day CI on this repo still runs the latest local composites (the **tag** remains a frozen snapshot; verify with **`git show v1.x.y:.github/workflows/ci.yml`**). When **`secrets-gitleaks`**, **`sast-bandit`**, or **`pip-audit-scan-action`** ship a new semver tag, update the matching **`uses:`** lines and cut a new **`workflow-python`** release if callers should pick it up via **`ci.yml@v…`**.

## Inputs

All inputs are optional; defaults assume `requirements.txt` at the repository root.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `working_directory` | string | `.` | Directory containing the Python project (relative to repo root). |
| `requirements_file` | string | `requirements.txt` | Fully **pinned** requirements path relative to `working_directory` (**pip-audit** `-r` target). Use a **pip-compile** lock for a stable transitive graph. |
| `enforce_pip_tools_lockfile` | boolean | `false` | If `true`, run **pip-compile** before **pip-audit** and fail when `requirements_file` is not reproducible from `pip_tools_requirements_in` (CI enforces lock discipline). |
| `pip_tools_requirements_in` | string | `requirements.in` | pip-compile **input** when `enforce_pip_tools_lockfile` is `true` (relative to `working_directory`). |
| `pip_tools_version` | string | `7.5.3` | Exact **pip-tools** version for the enforcement step. |
| `python_version` | string | `3.11` | Python version for Ruff, Bandit, and pip-audit jobs. |
| `fail_on_vuln` | boolean | `true` | If `true`, the pip-audit job fails when vulnerabilities are found. |
| `run_ruff` | boolean | `true` | If `false`, the Ruff job is skipped. |
| `ruff_version` | string | `0.15.9` | Exact Ruff version installed in the lint job. |
| `ruff_paths` | string | `.` | Space-separated paths relative to `working_directory` for `ruff check` / `ruff format`. |
| `ruff_config` | string | *(empty)* | Optional Ruff config path relative to `working_directory`. |
| `run_ruff_format` | boolean | `true` | If `false`, skip `ruff format --check`. |
| `ruff_fail_on_findings` | boolean | `true` | If `true`, the Ruff job fails when check or format reports work to do. |
| `run_pytest` | boolean | `true` | If `false`, the pytest job is skipped. |
| `pytest_requirements_file` | string | `requirements.txt` | Requirements file (relative to `working_directory`) for installing app deps before pytest. |
| `pytest_version` | string | `9.0.2` | Exact pytest version installed in the test job (match **`requirements.txt`** or override). |
| `pytest_args` | string | *(empty)* | Omit for auto: `-q tests` if `./tests` exists, else `-q test` if `./test` exists, else `-q`. Override with e.g. `-q .` or `-q mypkg/tests`. |
| `run_gitleaks` | boolean | `true` | If `false`, the Gitleaks job is skipped. |
| `run_pip_audit_scan` | boolean | `true` | If `false`, the pip-audit job is skipped. |
| `run_bandit` | boolean | `true` | If `false`, the Bandit job is skipped. |
| `bandit_config` | string | *(empty)* | Optional path to a Bandit config file relative to `working_directory` (for example `bandit.yaml`). |
| `bandit_exclude` | string | *(empty)* | Comma-separated paths excluded from Bandit (`--exclude`). Default **empty** scans **everything**, including `tests/` (good for catching risky patterns in test code). Set e.g. `tests` only if you want pytest `assert` noise (B101) out of Bandit without per-line `# nosec`. |
| `bandit_minimum_severity` | string | `all` | Bandit severity floor: `all`, `low`, `medium`, or `high`. Issues below this level are omitted from the report and do not fail the job. `medium` blocks on medium and high only. |
| `upload_code_scanning` | boolean | `true` | If `true`, **Gitleaks** and **Bandit** jobs write SARIF and upload to **Code Scanning** (Security tab / PR). Requires **`security-events: write`** on the **caller** job. Fork PRs from outside contributors may not upload (token limits). |

### When Bandit fails

Open the **bandit-scan** job log: Bandit prints **issue codes** (e.g. **B101**), **severity**, **file**, and a link to the plugin docs. Fix the code, add **`# nosec BXXX`** on a justified exception, or tune with **`bandit_config`** / **`bandit_exclude`** / **`bandit_minimum_severity`** (e.g. `medium` to ignore low-only noise — use with care).

**Pytest and B101:** Bandit flags **`assert`** because it is stripped under **`python -O`**. In **`tests/`**, **`assert`** is normal for pytest. With the default (scan tests), add **`# nosec B101`** on those lines, or set **`bandit_exclude: tests`** if you prefer not to annotate tests.

## Example: call from another repository

```yaml
name: App CI

permissions:
  contents: read
  security-events: write

on:
  pull_request:
    branches: [main]

jobs:
  security:
    uses: thadiust/workflow-python/.github/workflows/ci.yml@v1.0.5
    with:
      working_directory: "."
      requirements_file: "requirements.txt"
      python_version: "3.11"
      fail_on_vuln: true
      run_ruff: true
      ruff_version: "0.15.9"
      run_pytest: true
      pytest_version: "9.0.2"
      pytest_requirements_file: "requirements.txt"
      run_gitleaks: true
      run_pip_audit_scan: true
      run_bandit: true
      upload_code_scanning: true
      # enforce_pip_tools_lockfile: true
      # pip_tools_requirements_in: "requirements.in"
      # bandit_exclude: "tests"   # optional: omit tests/ from Bandit (e.g. avoid B101 on pytest asserts)
```

This workflow is **`workflow_call` only** (full inputs, no 10-key `workflow_dispatch` limit). Call it from an app repo with the **full** `with:` list (see table). To run **manually**, use **`workflow_dispatch`** on the **app** repo (e.g. [`sample-python-app`](https://github.com/thadiust/sample-python-app)), which still calls this file via **`workflow_call`**.

For controlled upgrades, call **`uses: …/ci.yml@v1.0.5`** (or another tag) instead of **`@main`**; bump the tag when you intentionally adopt a new release. That tag’s **`ci.yml`** pins **Ruff/pytest** to the same tag and lists **`thadiust/*`** versions (see supply chain note above).
