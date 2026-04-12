# workflow-python

**Branch `main` vs semver tags:** If you use this repo inside the [`security-pipeline`](../README.md) workspace, read **Branch `main` vs release tags** there first. In short: **`workflow-python` `main`** floats **all** nested **`thadiust/*`** refs at **`@main`** (solo dev). Use **`ci.yml@v…`** when you want a frozen snapshot.

**Lint in this repo:** [`.github/workflows/actionlint.yml`](.github/workflows/actionlint.yml) calls the reusable workflow **[`.github/workflows/reusable-actionlint.yml`](.github/workflows/reusable-actionlint.yml)** via **`uses: ./.github/workflows/reusable-actionlint.yml`** with **`validate_composite_actions: true`**. Other repositories can call **`thadiust/workflow-python/.github/workflows/reusable-actionlint.yml@main`** (solo dev) or **`@v…`** when you want a frozen snapshot. User-visible changes by tag are listed in **[CHANGELOG.md](CHANGELOG.md)**.

**Integration CI:** [`.github/workflows/dogfood-ci.yml`](.github/workflows/dogfood-ci.yml) runs the full **`ci.yml`** graph against the tiny **[`dogfood/`](dogfood/)** fixture when workflow or action code changes. **[`.github/workflows/scheduled-security-scan.yml`](.github/workflows/scheduled-security-scan.yml)** repeats that on a **weekly** schedule (enable **Actions → Scheduled workflows** in repo settings if GitHub requires it). **[`.github/workflows/scheduled-trivy-unfixed-report.yml`](.github/workflows/scheduled-trivy-unfixed-report.yml)** runs **Trivy** on **`dogfood/`** with **`ignore_unfixed: false`** (**report-only** — does not fail) for **unfixed CVE visibility** without changing the main gate default. Leave integration workflows **on** so **`ci.yml`** regressions surface here before consumer apps. **[`MAINTAINERS.md`](MAINTAINERS.md)** is the short checklist for **default version bumps**, **hash constraint scripts**, **Dependabot**, and **CHANGELOG** habits. **[`ORG_PORTABILITY.md`](ORG_PORTABILITY.md)** explains replacing **`thadiust/…`** under another org. **[`SECURITY.md`](SECURITY.md)** is the vulnerability reporting policy. **[`CI_RISK_REGISTER.md`](CI_RISK_REGISTER.md)** is the **threat / policy** cross-check; **[`COMPANY_RUNBOOK.md`](COMPANY_RUNBOOK.md)** is the **severity-ranked rollout checklist** (fork policy, Trivy policy, hashes, Dependency Review, SAST scope, artifacts).

**Dependency Review** is **not** part of the **`ci.yml`** DAG. For **PR onboarding**, call **[`python-pr-suite.yml`](.github/workflows/python-pr-suite.yml)** (**Dependency Review** ∥ **`ci.yml`**) with optional forwarded inputs (lockfile, Docker, Trivy image gate — see workflow file), or copy **[`examples/consumer-pull-request-ci.yml`](examples/consumer-pull-request-ci.yml)**. A **minimal** two-job template is also below.

Reusable GitHub Actions workflow for Python security checks. App repositories call [`.github/workflows/ci.yml`](.github/workflows/ci.yml), which runs:

1. **[Ruff](https://docs.astral.sh/ruff/)** via [`.github/actions/ruff`](.github/actions/ruff/README.md) (**`thadiust/workflow-python/.github/actions/ruff@main`** from callers — not `./…`, which resolves on the **caller** checkout). **`ruff check`**, optional **`ruff format --check`**, pinned **`ruff_version`**, **`--force-exclude`**. Toggle **`run_ruff`**.
2. **[Gitleaks](https://github.com/gitleaks/gitleaks)** via [`thadiust/secrets-gitleaks`](https://github.com/thadiust/secrets-gitleaks) (**`…/secrets-gitleaks@main`**). **Runs in parallel with Ruff** and does **not** wait on **pytest** — fast secrets detection before slow tests. **`fetch-depth: 0`** for full history. **Locally**, run **Gitleaks** (and **Ruff**) in **[pre-commit](https://pre-commit.com/)** so secrets never enter history; CI mirrors that priority. See [**Removed the file, but CI still fails?**](https://github.com/thadiust/secrets-gitleaks/blob/main/README.md#removed-the-file-but-ci-still-fails). Toggle **`run_gitleaks`**.
3. **[pytest](https://pytest.org/)** via [`.github/actions/pytest`](.github/actions/pytest/README.md) — **`needs`** **`ruff-lint`** and **`gitleaks-scan`** so **slow tests run only after** lint + secrets gate (each may be **skipped** only when its toggle is off). Toggle **`run_pytest`**.
4. **[Trivy](https://github.com/aquasecurity/trivy)** (**fs** + **config**) via [`thadiust/trivy-scan`](https://github.com/thadiust/trivy-scan) (**`…/trivy-scan@main`**). **`trivy-repo-scan`** **`needs`** **Ruff**, **Gitleaks**, and **pytest** (same pattern as Bandit/pip-audit) — **deliberate** so **tests fail before** heavier scanners spend minutes; for **earliest** fs/IaC signal only, run a separate workflow or fork the DAG. Toggle **`run_trivy`** and **`trivy_*`**.
5. **[Bandit](https://github.com/pycqa/bandit)** and **[pip-audit](https://github.com/pypa/pip-audit)** via **`sast-bandit`** / **`pip-audit-scan-action`** — **`needs`** **Ruff**, **Gitleaks**, **pytest**; **in parallel with each other and with Trivy repo** after pytest. Toggle **`run_bandit`**, **`run_pip_audit_scan`**.
6. Optional **`docker-build`** then **`trivy-image-scan`** (leaf): **`docker-build`** **`needs`** **Ruff**, **Gitleaks**, **pytest**, **Trivy repo**, **Bandit**, **pip-audit** — image only after that wave (**`run_docker_build`**, **`run_trivy_image_scan`**, **`trivy_image_fail_on_findings`**, etc.).

**Toggle jobs** with **`run_ruff`**, **`run_gitleaks`**, **`run_pytest`**, **`run_trivy`**, **`run_bandit`**, **`run_pip_audit_scan`**, **`run_docker_build`**, **`run_trivy_image_scan`**. If **every** job is disabled, GitHub rejects the run — leave at least one enabled.

**DAG summary:** **Ruff ∥ Gitleaks** → **pytest** → **Trivy repo ∥ Bandit ∥ pip-audit** → optional **Docker** → optional **Trivy image**.

### SAST scope (Bandit)

**Bandit** is a **pattern-based** Python SAST tool (plugins, AST hooks). It is **not** a full **semantic** or **inter-procedural** analyzer. **Regulated** or **enterprise AppSec** programs should **plan** **CodeQL**, **SonarQube** / **SonarCloud**, or another product **in addition** if policy expects that depth — see **[`COMPANY_RUNBOOK.md`](COMPANY_RUNBOOK.md)**.

### Pip, lockfiles, and SCA (why `requirements.in` + `requirements.txt`)

**pip-audit** reports vulnerabilities for the **dependency graph implied by the file** you pass to `-r`. A hand-edited `requirements.txt` with only top-level pins still leaves **transitive versions** to the resolver at install time unless you record them. **pip-tools** separates concerns:

- **`requirements.in`** — what you intend (ranges or top-level pins).
- **`requirements.txt`** — **fully pinned** output from **`pip-compile`** (transitives included).

Turn **`enforce_pip_tools_lockfile: true`** so CI runs **`actions/setup-python`** with **`python_version`**, then **`pip-compile … -o requirements.txt`** and **`git diff --exit-code`** on the lock: if someone edits **`.in`** without regenerating the lock, the job fails. Point **`pytest_requirements_file`** at the **same lock** as **`requirements_file`** so tests and SCA see one graph.

**Other package managers:** This reusable workflow is built around **`pip`** + a **`requirements.txt`** graph for **pytest** installs and **pip-audit**. **Poetry**, **uv**, **PDM**, or **`pyproject.toml`‑only** flows are **not** wired in **`ci.yml`**; export a **pinned** **`requirements.txt`** (or add a caller workflow that materializes one before **`workflow_call`**) or maintain a **fork** with native lockfile steps.

### Terminology

Across these jobs, a **finding** is anything that can fail the pipeline when the matching toggle and fail mode are on:

| Job | Finding type | Typical output |
|-----|----------------|----------------|
| Ruff | **Lint / format** | `scan_status`, `format_ok` |
| Gitleaks | **Secrets** | `secret_count` |
| Bandit | **Issues** (SAST) | `issue_count` |
| pip-audit | **Vulnerabilities** (dependencies) | `vuln_count` |

## Security and cost

### Supported runners and tooling

**`ci.yml`** is validated on **GitHub-hosted `ubuntu-latest`** (**linux/amd64**). Nested composites (**[`secrets-gitleaks`](https://github.com/thadiust/secrets-gitleaks)**, **[`trivy-scan`](https://github.com/thadiust/trivy-scan)**, etc.) download **Linux x86_64** binaries and use **`jq`** on **`PATH`** for counts. **[`reusable-actionlint.yml`](.github/workflows/reusable-actionlint.yml)** fetches **actionlint** **`linux_amd64`** only. **ARM** or **minimal** runners without **`jq`** require changes to those actions or your runner image before this pipeline is reliable.

### Public repositories and fork pull requests

**Fork PR** workflows use a **read-scoped** token and **do not** receive base-repo **secrets** under GitHub’s default model—**do not** redesign workflows to inject **secrets** into jobs that execute untrusted PR code. Malicious or noisy PRs can still **use Actions minutes**; review **concurrency**, **permissions**, and **cache** usage against GitHub’s guidance for public repositories.

**Fork / public expectations (features):** **SARIF** upload (**`upload_code_scanning`**) may **fail or no-op** on fork PRs depending on token scope and **GitHub Advanced Security** — steps use **`continue-on-error: true`** so CI can stay green while uploads are skipped. **[`dependency-review.yml`](.github/workflows/dependency-review.yml)** is typically **PR-only**; forks follow GitHub’s same permission rules as your org’s policy. Set onboarding expectations accordingly.

### Opinionated `workflow_call` inputs

**`ci.yml`** forwards **tool versions** (**`gitleaks_version`**, **`bandit_version`**, **`pip_audit_version`**) and **`bandit_targets`**. It still **does not** expose every composite knob (e.g. Bandit **`report_format`**, Gitleaks **`baseline_path`**, pip-audit **`report_file`**). For those, **fork** and extend **`workflow_call`** inputs or wrap a job.

- **Token scope:** The workflow sets **`permissions: contents: read`** so the default `GITHUB_TOKEN` is not granted write access it does not need.
- **Checkout:** Jobs use **`persist-credentials: false`** so the credential helper is not left configured for later steps. Gitleaks uses **`fetch-depth: 0`** (full history); Trivy repo/image, Bandit, and pip-audit use **`fetch-depth: 1`** (current commit only) to avoid cloning full history on extra runners. The built image is passed to **Trivy image** with **`upload-artifact`** / **`download-artifact`** (**1-day** retention on the tarball). **Do not bake secrets** into images; confirm **artifact read** permissions match org policy (anyone who can read workflow artifacts can download the tarball for the retention window).
- **Concurrency:** This workflow defines a **`concurrency`** group (per repository and ref) with **`cancel-in-progress: true`** so superseded runs are dropped when the same branch is pushed again. If your **caller** workflow defines its own `concurrency`, GitHub applies the caller’s rules for the whole run; avoid defining two competing groups for the same jobs.
- **Fast-then-slow (deliberate):** **Gitleaks** does **not** wait on **pytest**; it runs with **Ruff** in the first wave so secrets are caught before slow installs/tests. **pytest** waits on **Ruff** + **Gitleaks**. **Trivy repo**, **Bandit**, and **pip-audit** wait on **Ruff** + **Gitleaks** + **pytest**, then run **in parallel**. **Docker build** waits on all of those (each **skipped** only when its toggle is off). **Trivy image** is a **leaf**.
- **Parallel jobs vs minutes:** **`runner-info`** logs **`runner.*`** once (toggle **`run_runner_info: false`** to drop that job). **Ruff** and **Gitleaks** can run together; then **pytest**; then up to **three** scanners in parallel. Optional **Docker** / **Trivy image** add runners. Disable jobs via inputs to save minutes.
- **Timeouts:** Ruff uses **`timeout-minutes: 15`**; other jobs use **`timeout-minutes: 30`** so a hung scanner does not burn the runner default (6 hours).
- **Supply chain:** On **`workflow-python` branch `main`**, **`ci.yml`** uses **`@main`** for **Ruff**, **pytest**, **Trivy**, **`secrets-gitleaks`**, **`sast-bandit`**, and **`pip-audit-scan-action`** (solo-dev floating pins). For reproducible upgrades, **consumers** can call **`ci.yml@v…`** and rely on whatever nested pins that tag records. **`upload_code_scanning`** (default **`true`**) uploads **Gitleaks**, **Bandit**, **Trivy repo** (**`trivy`**), and **Trivy image** (**`trivy-image`**) SARIF via **`github/codeql-action/upload-sarif`** — caller workflows need **`permissions: security-events: write`** on the job that **`uses`** this workflow (see example). Upload steps use **`continue-on-error: true`** so missing **GitHub Advanced Security** does not fail the pipeline.
- **Pip hash pinning:** **Ruff** and the **pytest** *tool* install use **`pip --require-hashes`** when a matching **`constraints/*.txt`** exists; other versions log a **warning**. The **application** graph from **`pip install -r`** (**`pytest_requirements_file`**) is **not** hash-verified unless that file contains **PEP 503** hashes (e.g. **`pip-compile --generate-hashes`**) — or you set **`pytest_app_require_hashes: true`** on **`ci.yml`** (then **`pip install -r`** uses **`--require-hashes`** and **must** match a hash-mode lock). **Lockfile enforcement** uses **[`install-pip-tools-hashed`](.github/actions/install-pip-tools-hashed/action.yml)** only when **`pip_tools_version`** is **exactly `7.5.3`**; any other value uses **plain** **`pip install pip-tools==…`**. Set **`pip_tools_require_hashed_install: true`** with **`enforce_pip_tools_lockfile: true`** to **fail** if **`pip_tools_version`** is not **`7.5.3`** until you extend bundled constraints (see **[`CI_RISK_REGISTER.md`](CI_RISK_REGISTER.md)**). **reusable-actionlint** uses **[`install-pyyaml-hashed`](.github/actions/install-pyyaml-hashed/action.yml)**. **Bandit** (**`sast-bandit`**) and **pip-audit** (**`pip-audit-scan-action`**) use the same pattern: hashed installs for their **default** versions bundled in those repos; custom **`bandit_version`** / **`pip_audit_version`** or missing constraint files fall back with **`::warning`**. Regenerate: **[`scripts/refresh-pip-constraints.sh`](scripts/refresh-pip-constraints.sh)** here; **`sast-bandit`** / **`scan-pip-audit`** each ship **`scripts/refresh-pip-constraints.sh`** for their constraint files.
- **`trivy_ignore_unfixed` (policy):** Default **`true`** hides **unfixed** CVEs from fail logic — good for merge noise; set **`false`** if the org wants **unfixable** issues visible in the gate, or add a **second** reporting-only workflow for visibility.
- **Pre-commit vs CI:** **Ruff** + **Gitleaks** in CI are the **enforced** contract. **[pre-commit](https://pre-commit.com/)** is **recommended locally** (see job list above) but **not** run as a CI job here; add your own optional pre-commit workflow if the org wants hooks identical to developers’ machines.

### Reusable actionlint (for other repositories)

[`reusable-actionlint.yml`](.github/workflows/reusable-actionlint.yml) runs **actionlint** on workflow files and optionally validates YAML for:

| Input | Use case |
|-------|-----------|
| **`validate_composite_actions: true`** | Repos with **`.github/actions/**/action.yml`** (like this repo). |
| **`validate_root_action_yml: true`** | Standalone composite actions with **`action.yml`** at repo root. |
| *(omit both)* | App repos with workflows only (e.g. **sample-python-app**). |

Callers: **`uses: thadiust/workflow-python/.github/workflows/reusable-actionlint.yml@main`** (or **`@v…`** when pinned).

### Releasing a new semver tag (`v1.x.y`)

See **[`MAINTAINERS.md`](MAINTAINERS.md)** for the full **bump → script → constraints** table (including **Bandit** / **pip-audit** in nested repos).

1. Update **[CHANGELOG.md](CHANGELOG.md)** with a **`[v1.x.y]`** section (optional for solo-only nits if you prefer).
2. **Pip hash constraints:** If you change default **`ruff_version`**, **`pytest_version`**, **`pip_tools_version`** (default **7.5.3**), or the **PyYAML** version bundled in **[`install-pyyaml-hashed`](.github/actions/install-pyyaml-hashed/)**, run **[`scripts/refresh-pip-constraints.sh`](scripts/refresh-pip-constraints.sh)** and commit the updated **`constraints*.txt`** files. Skipping this keeps CI working but emits **`::warning`** and uses unhashed **`pip install`** for those tools (see **[`ORG_PORTABILITY.md`](ORG_PORTABILITY.md)** and **`MAINTAINERS.md`**).
3. In [`.github/workflows/ci.yml`](.github/workflows/ci.yml), set **`thadiust/workflow-python/.github/actions/ruff@v1.x.y`** and **`…/pytest@v1.x.y`** to match the tag you are about to create (so **`ci.yml@v1.x.y`** and the composites resolve to the same commit). Pin **`thadiust/trivy-scan`**, **`secrets-gitleaks`**, **`sast-bandit`**, and **`pip-audit-scan-action`** to the semver tags you want that release to ship.
4. Commit, create the annotated tag **`v1.x.y`**, push **`main`** and **`git push origin v1.x.y`**.
5. On **`main`**, follow up with a commit that sets **Ruff**, **pytest**, **Trivy**, **`secrets-gitleaks`**, **`sast-bandit`**, and **`pip-audit-scan-action`** back to **`@main`** so day-to-day CI floats latest (the **tag** remains a frozen snapshot; verify with **`git show v1.x.y:.github/workflows/ci.yml`**). When cutting a release tag, pin those **`uses:`** lines to **`@v…`** as needed for reproducibility.

## Inputs

All inputs are optional; defaults assume `requirements.txt` at the repository root.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `working_directory` | string | `.` | Directory containing the Python project (relative to repo root). |
| `requirements_file` | string | `requirements.txt` | Fully **pinned** requirements path relative to `working_directory` (**pip-audit** `-r` target). Use a **pip-compile** lock for a stable transitive graph. |
| `enforce_pip_tools_lockfile` | boolean | `false` | If `true`, run **pip-compile** before **pip-audit** and fail when `requirements_file` is not reproducible from `pip_tools_requirements_in` (CI enforces lock discipline). |
| `pip_tools_requirements_in` | string | `requirements.in` | pip-compile **input** when `enforce_pip_tools_lockfile` is `true` (relative to `working_directory`). |
| `pip_tools_version` | string | `7.5.3` | Exact **pip-tools** version for the enforcement step. |
| `pip_tools_require_hashed_install` | boolean | `false` | If **`true`** with **`enforce_pip_tools_lockfile`**, fail when **`pip_tools_version`** ≠ **`7.5.3`** (no bundled hash constraints for other versions). |
| `python_version` | string | `3.11` | Python version for Ruff, Bandit, and pip-audit jobs (Trivy is a standalone binary; this input does not affect Trivy). |
| `fail_on_vuln` | boolean | `true` | If `true`, the pip-audit job fails when vulnerabilities are found. |
| `pip_audit_version` | string | `2.7.3` | Exact **pip-audit** version (**`pip-audit-scan-action`**). |
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
| `pytest_app_require_hashes` | boolean | `false` | If **`true`**, **`pip install -r pytest_requirements_file`** uses **`--require-hashes`** (file must include **PEP 503** hashes). |
| `run_trivy` | boolean | `true` | If `false`, the Trivy job is skipped. |
| `trivy_version` | string | `0.69.3` | Exact Trivy release version (no `v` prefix); must exist upstream. |
| `trivy_mode` | string | `both` | `fs`, `config`, or `both`. |
| `trivy_paths` | string | `.` | Space-separated paths relative to `working_directory` for Trivy. |
| `trivy_severity` | string | `HIGH,CRITICAL` | Comma-separated severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL). |
| `trivy_ignore_unfixed` | boolean | `true` | If `true`, **unfixed** CVEs are omitted from the Trivy gate (merge noise). Set **`false`** if policy requires them visible, or use a separate reporting workflow. |
| `trivy_fail_on_findings` | boolean | `true` | If `true`, the **repository** Trivy job (**fs**/**config**) fails when findings are reported. |
| `trivy_image_fail_on_findings` | boolean | `true` | If `true`, the **container image** Trivy job fails on findings (aligned with **`trivy_fail_on_findings`**). Set **`false`** only if you accept a green CI while still uploading SARIF — e.g. noisy base images — and document why in the caller repo. |
| `run_docker_build` | boolean | `false` | If `true`, build a Docker image only after **Ruff**, **Gitleaks**, **pytest**, **Trivy repo**, **Bandit**, and **pip-audit** have each succeeded or been skipped (toggle off), then upload a tarball for **`trivy-image-scan`**. |
| `dockerfile` | string | `Dockerfile` | Dockerfile path relative to the build context. |
| `docker_context` | string | *(empty)* | Context directory relative to repo root; empty uses **`working_directory`**. |
| `docker_image_tag` | string | `workflow-python-ci:scan` | Local tag for **`docker build`**, **`docker save`/`load`**, and **`trivy image`**. |
| `run_trivy_image_scan` | boolean | `true` | When **`run_docker_build`** is `true`, run **Trivy** on the built image (leaf job). |
| `run_gitleaks` | boolean | `true` | If `false`, the Gitleaks job is skipped. |
| `gitleaks_version` | string | `8.18.4` | Exact **Gitleaks** release (**`secrets-gitleaks`**). |
| `run_pip_audit_scan` | boolean | `true` | If `false`, the pip-audit job is skipped. |
| `run_bandit` | boolean | `true` | If `false`, the Bandit job is skipped. |
| `bandit_config` | string | *(empty)* | Optional path to a Bandit config file relative to `working_directory` (for example `bandit.yaml`). |
| `bandit_exclude` | string | *(empty)* | Comma-separated paths excluded from Bandit (`--exclude`). Default **empty** scans **everything**, including `tests/` (good for catching risky patterns in test code). Set e.g. `tests` only if you want pytest `assert` noise (B101) out of Bandit without per-line `# nosec`. |
| `bandit_targets` | string | `.` | Space-separated paths relative to `working_directory` passed to Bandit **`-r`** (e.g. `src` or `src tests`). |
| `bandit_minimum_severity` | string | `all` | Bandit severity floor: `all`, `low`, `medium`, or `high`. Issues below this level are omitted from the report and do not fail the job. `medium` blocks on medium and high only. |
| `bandit_version` | string | `1.9.4` | Exact **Bandit** version (**`sast-bandit`**). With **`upload_code_scanning`**, Bandit may run **twice** (JSON + SARIF) — see **`sast-bandit`** README. |
| `upload_code_scanning` | boolean | `true` | If `true`, **Gitleaks**, **Bandit**, **Trivy repo**, and **Trivy image** jobs write SARIF and upload to **Code Scanning** (Security tab / PR). Requires **`security-events: write`** on the **caller** job. Fork PRs from outside contributors may not upload (token limits). |
| `run_runner_info` | boolean | `true` | If `false`, skip the **`runner-info`** job (saves one job; no impact on scan results). |

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

### Example: Dependency Review on pull requests

**Preferred:** Call **`python-pr-suite.yml`** so **Dependency Review** and **`ci.yml`** run together (see **[`examples/consumer-pull-request-ci.yml`](examples/consumer-pull-request-ci.yml)**).

**[`dependency-review.yml`](.github/workflows/dependency-review.yml)** is **`workflow_call`** only — it does **not** run automatically when you call **`ci.yml`** alone. Minimal **consumer** workflow (Dependency Review **only** — adjust **`@main`** / **`@v…`** to match how you pin **`ci.yml`**):

```yaml
name: Dependency Review

on:
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: read

jobs:
  dependency-review:
    uses: thadiust/workflow-python/.github/workflows/dependency-review.yml@main
```

If your org restricts **`pull-requests: read`**, follow [GitHub’s dependency review docs](https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/about-dependency-review) for required permissions.
