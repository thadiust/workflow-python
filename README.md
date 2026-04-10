# workflow-python

**Branch `main` vs semver tags:** If you use this repo inside the [`security-pipeline`](../README.md) workspace, read **Branch `main` vs release tags** there first. In short: **`workflow-python` `main`** floats **all** nested **`thadiust/*`** refs at **`@main`** (solo dev). Use **`ci.yml@v…`** when you want a frozen snapshot.

**Lint in this repo:** [`.github/workflows/actionlint.yml`](.github/workflows/actionlint.yml) calls the reusable workflow **[`.github/workflows/reusable-actionlint.yml`](.github/workflows/reusable-actionlint.yml)** via **`uses: ./.github/workflows/reusable-actionlint.yml`** with **`validate_composite_actions: true`**. Other repositories can call **`thadiust/workflow-python/.github/workflows/reusable-actionlint.yml@main`** (solo dev) or **`@v…`** when you want a frozen snapshot. User-visible changes by tag are listed in **[CHANGELOG.md](CHANGELOG.md)**.

Reusable GitHub Actions workflow for Python security checks. App repositories call [`.github/workflows/ci.yml`](.github/workflows/ci.yml), which runs:

1. **[Ruff](https://docs.astral.sh/ruff/)** via the composite at [`.github/actions/ruff`](.github/actions/ruff/README.md). On branch **`main`**, [`ci.yml`](.github/workflows/ci.yml) references **`thadiust/workflow-python/.github/actions/ruff@main`** (not `./…`: with a **reusable workflow** called from another repo, **local `./` paths resolve on the caller’s checkout**, so composites must use the **`owner/repo`** form). **Semver tags** (e.g. **`v1.0.8`**) pin **`…/ruff@v1.0.8`** alongside **`ci.yml@v1.0.8`**. `ruff check` (GitHub annotations) and optional `ruff format --check`, pinned version, **`--force-exclude`**. Toggle with `run_ruff` and related inputs.
2. **[pytest](https://pytest.org/)** via [`.github/actions/pytest`](.github/actions/pytest/README.md) (**`@main`** on branch **main**; **`@v1.0.x`** on matching release tags), **in parallel** with Ruff when both are enabled (`run_pytest`). Installs deps from `pytest_requirements_file` and runs `python -m pytest` with `pytest_args`; pytest itself is pinned to `pytest_version`.
3. **[Trivy](https://github.com/aquasecurity/trivy)** (**Wave 1** filesystem + config) via [`thadiust/trivy-scan`](https://github.com/thadiust/trivy-scan) (**`uses: …/trivy-scan@main`** on branch **main** — tag that repo to bump). **`trivy-scan`** has **no `needs`**, so it runs **in parallel** with **Ruff** and **pytest** (and still runs if those jobs fail, unless you cancel the workflow). Toggle with `run_trivy` and related inputs (`trivy_mode`, `trivy_paths`, `trivy_severity`, etc.).
4. **[Gitleaks](https://github.com/gitleaks/gitleaks)** via [`thadiust/secrets-gitleaks`](https://github.com/thadiust/secrets-gitleaks) (**`uses: …/secrets-gitleaks@main`** on branch **`workflow-python` `main`** — pin tags when you want reproducibility). Secrets; **full git history** — checkout uses `fetch-depth: 0`. **`gitleaks-scan`** **`needs`** **`ruff-lint`** and **`pytest-test`**. See [**Removed the file, but CI still fails?**](https://github.com/thadiust/secrets-gitleaks/blob/main/README.md#removed-the-file-but-ci-still-fails) in the action README.
5. After Gitleaks: **[Bandit](https://github.com/pycqa/bandit)** via [`thadiust/sast-bandit`](https://github.com/thadiust/sast-bandit) (**`…/sast-bandit@main`**) and **[pip-audit](https://github.com/pypa/pip-audit)** via [`thadiust/pip-audit-scan-action`](https://github.com/thadiust/pip-audit-scan-action) (**`…/pip-audit-scan-action@main`**) — dependency **vulnerabilities** (in parallel with each other).

**Bandit** and **pip-audit** each **`needs`** **`ruff-lint`**, **`gitleaks-scan`**, and **`pytest-test`**. If **pytest fails**, **Gitleaks**, **Bandit**, and **pip-audit** **do not run** (no secrets/SAST/SCA on that run — fix tests or use toggles if you need a different policy). **Trivy** is **not** gated on Ruff/pytest in the default graph. If **Gitleaks fails**, Bandit and pip-audit are skipped. `run_pytest: false` skips the pytest job so downstream jobs still run when other gates pass. Toggle jobs with `run_ruff`, `run_pytest`, `run_trivy`, `run_gitleaks`, `run_bandit`, and `run_pip_audit_scan`. If **every** job is disabled, the workflow has no jobs and GitHub will reject the run — leave at least one enabled.

This layout runs **Ruff**, **pytest**, and **Trivy** in parallel (when enabled), then **secrets** after Ruff/pytest, then **SAST (Bandit)** and **SCA (pip-audit)**; Bandit and pip-audit stay **independent** of each other.

### Pip, lockfiles, and SCA (why `requirements.in` + `requirements.txt`)

**pip-audit** reports vulnerabilities for the **dependency graph implied by the file** you pass to `-r`. A hand-edited `requirements.txt` with only top-level pins still leaves **transitive versions** to the resolver at install time unless you record them. **pip-tools** separates concerns:

- **`requirements.in`** — what you intend (ranges or top-level pins).
- **`requirements.txt`** — **fully pinned** output from **`pip-compile`** (transitives included).

Turn **`enforce_pip_tools_lockfile: true`** so CI runs **`actions/setup-python`** with **`python_version`**, then **`pip-compile … -o requirements.txt`** and **`git diff --exit-code`** on the lock: if someone edits **`.in`** without regenerating the lock, the job fails. Point **`pytest_requirements_file`** at the **same lock** as **`requirements_file`** so tests and SCA see one graph.

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
- **Checkout:** Jobs use **`persist-credentials: false`** so the credential helper is not left configured for later steps. Gitleaks uses **`fetch-depth: 0`** (full history); Trivy, Bandit, and pip-audit use **`fetch-depth: 1`** (current commit only) to avoid cloning full history on extra runners.
- **Concurrency:** This workflow defines a **`concurrency`** group (per repository and ref) with **`cancel-in-progress: true`** so superseded runs are dropped when the same branch is pushed again. If your **caller** workflow defines its own `concurrency`, GitHub applies the caller’s rules for the whole run; avoid defining two competing groups for the same jobs.
- **Tests before security scans (deliberate):** **Gitleaks**, **Bandit**, and **pip-audit** run only after **Ruff** and **pytest** succeed (or are skipped via toggles). If **pytest fails**, those jobs **do not run** — fewer CI minutes and a clear “fix tests first” signal. **Trivy** is **not** in that gate by default (it runs in parallel with Ruff/pytest). Some orgs prefer secrets/SCA even on red tests; this workflow does **not** do that unless you fork and change **`needs:`** / **`if:`**.
- **Parallel jobs vs minutes:** **`runner-info`** logs documented **`runner.*`** fields (`os`, `arch`, `environment`, `name`) once — **`runner.environment`** shows **`github-hosted`** vs **`self-hosted`**. **Ruff**, **pytest**, and **Trivy** can run **in parallel** (up to three extra runners when all are enabled). **Gitleaks** starts only after **both** Ruff and pytest finish (**success or skipped**). After Gitleaks, **Bandit** and **pip-audit** run **at the same time** (two more runners). **Billed minutes** sum across all jobs. Disable jobs you do not need via inputs to save time.
- **Timeouts:** Ruff uses **`timeout-minutes: 15`**; other jobs use **`timeout-minutes: 30`** so a hung scanner does not burn the runner default (6 hours).
- **Supply chain:** On **`workflow-python` branch `main`**, **`ci.yml`** uses **`@main`** for **Ruff**, **pytest**, **Trivy**, **`secrets-gitleaks`**, **`sast-bandit`**, and **`pip-audit-scan-action`** (solo-dev floating pins). For reproducible upgrades, **consumers** can call **`ci.yml@v…`** and rely on whatever nested pins that tag records. **`upload_code_scanning`** (default **`true`**) uploads **Gitleaks**, **Bandit**, and **Trivy** SARIF via **`github/codeql-action/upload-sarif`** — caller workflows need **`permissions: security-events: write`** on the job that **`uses`** this workflow (see example). Upload steps use **`continue-on-error: true`** so missing **GitHub Advanced Security** does not fail the pipeline.

### Reusable actionlint (for other repositories)

[`reusable-actionlint.yml`](.github/workflows/reusable-actionlint.yml) runs **actionlint** on workflow files and optionally validates YAML for:

| Input | Use case |
|-------|-----------|
| **`validate_composite_actions: true`** | Repos with **`.github/actions/**/action.yml`** (like this repo). |
| **`validate_root_action_yml: true`** | Standalone composite actions with **`action.yml`** at repo root. |
| *(omit both)* | App repos with workflows only (e.g. **sample-python-app**). |

Callers: **`uses: thadiust/workflow-python/.github/workflows/reusable-actionlint.yml@main`** (or **`@v…`** when pinned).

### Releasing a new semver tag (`v1.x.y`)

1. Update **[CHANGELOG.md](CHANGELOG.md)** with a **`[v1.x.y]`** section.
2. In [`.github/workflows/ci.yml`](.github/workflows/ci.yml), set **`thadiust/workflow-python/.github/actions/ruff@v1.x.y`** and **`…/pytest@v1.x.y`** to match the tag you are about to create (so **`ci.yml@v1.x.y`** and the composites resolve to the same commit). Pin **`thadiust/trivy-scan`**, **`secrets-gitleaks`**, **`sast-bandit`**, and **`pip-audit-scan-action`** to the semver tags you want that release to ship.
3. Commit, create the annotated tag **`v1.x.y`**, push **`main`** and **`git push origin v1.x.y`**.
4. On **`main`**, follow up with a commit that sets **Ruff**, **pytest**, **Trivy**, **`secrets-gitleaks`**, **`sast-bandit`**, and **`pip-audit-scan-action`** back to **`@main`** so day-to-day CI floats latest (the **tag** remains a frozen snapshot; verify with **`git show v1.x.y:.github/workflows/ci.yml`**). When cutting a release tag, pin those **`uses:`** lines to **`@v…`** as needed for reproducibility.

## Inputs

All inputs are optional; defaults assume `requirements.txt` at the repository root.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `working_directory` | string | `.` | Directory containing the Python project (relative to repo root). |
| `requirements_file` | string | `requirements.txt` | Fully **pinned** requirements path relative to `working_directory` (**pip-audit** `-r` target). Use a **pip-compile** lock for a stable transitive graph. |
| `enforce_pip_tools_lockfile` | boolean | `false` | If `true`, run **pip-compile** before **pip-audit** and fail when `requirements_file` is not reproducible from `pip_tools_requirements_in` (CI enforces lock discipline). |
| `pip_tools_requirements_in` | string | `requirements.in` | pip-compile **input** when `enforce_pip_tools_lockfile` is `true` (relative to `working_directory`). |
| `pip_tools_version` | string | `7.5.3` | Exact **pip-tools** version for the enforcement step. |
| `python_version` | string | `3.11` | Python version for Ruff, Bandit, and pip-audit jobs (Trivy is a standalone binary; this input does not affect Trivy). |
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
| `run_trivy` | boolean | `true` | If `false`, the Trivy job is skipped. |
| `trivy_version` | string | `0.69.3` | Exact Trivy release version (no `v` prefix); must exist upstream. |
| `trivy_mode` | string | `both` | `fs`, `config`, or `both`. |
| `trivy_paths` | string | `.` | Space-separated paths relative to `working_directory` for Trivy. |
| `trivy_severity` | string | `HIGH,CRITICAL` | Comma-separated severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL). |
| `trivy_ignore_unfixed` | boolean | `true` | If `true`, ignore vulnerabilities without a fix. |
| `trivy_fail_on_findings` | boolean | `true` | If `true`, the Trivy job fails when findings are reported. |
| `run_gitleaks` | boolean | `true` | If `false`, the Gitleaks job is skipped. |
| `run_pip_audit_scan` | boolean | `true` | If `false`, the pip-audit job is skipped. |
| `run_bandit` | boolean | `true` | If `false`, the Bandit job is skipped. |
| `bandit_config` | string | *(empty)* | Optional path to a Bandit config file relative to `working_directory` (for example `bandit.yaml`). |
| `bandit_exclude` | string | *(empty)* | Comma-separated paths excluded from Bandit (`--exclude`). Default **empty** scans **everything**, including `tests/` (good for catching risky patterns in test code). Set e.g. `tests` only if you want pytest `assert` noise (B101) out of Bandit without per-line `# nosec`. |
| `bandit_minimum_severity` | string | `all` | Bandit severity floor: `all`, `low`, `medium`, or `high`. Issues below this level are omitted from the report and do not fail the job. `medium` blocks on medium and high only. |
| `upload_code_scanning` | boolean | `true` | If `true`, **Gitleaks**, **Bandit**, and **Trivy** jobs write SARIF and upload to **Code Scanning** (Security tab / PR). Requires **`security-events: write`** on the **caller** job. Fork PRs from outside contributors may not upload (token limits). |

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
    uses: thadiust/workflow-python/.github/workflows/ci.yml@main
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

For reproducible upgrades, call **`uses: …/ci.yml@v…`** instead of **`@main`**; that snapshot’s **`ci.yml`** records whatever nested **`thadiust/*`** pins the release chose. While solo, **`@main`** tracks latest on **`workflow-python`** and nested actions (see supply chain note above).
