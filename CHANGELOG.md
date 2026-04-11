# Changelog

All notable changes to **workflow-python** are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [semantic versioning](https://semver.org/) for tags (`v1.x.y`).

## [Unreleased]

### Added

- **[`MAINTAINERS.md`](MAINTAINERS.md):** default version bump → **`scripts/refresh-pip-constraints.sh`** map (this repo + **sast-bandit** / **pip-audit-scan-action**), keep **dogfood** + **scheduled** workflows on, **Dependabot** and **CHANGELOG** guidance.

### Fixed

- **Dogfood / Bandit:** **`sast-bandit`** now installs **`bandit[sarif]`** so **Code Scanning** SARIF works on PyPI **Bandit**; dogfood test uses **`# nosec B101`** for pytest **`assert`**.
- **`run_pytest`** / **`run_gitleaks`** input descriptions and **`run_docker_build`** README row aligned with **`ci.yml`**: pytest after **Ruff** + **Gitleaks**; Gitleaks **parallel** with Ruff; Docker build waits on all six upstream jobs.

### Changed

- **README** / **[`ORG_PORTABILITY.md`](ORG_PORTABILITY.md):** **`pip --require-hashes`** for nested **`sast-bandit`** / **`pip-audit-scan-action`** defaults; release checklist ties **`ruff_version`** / **`pytest_version`** / **`pip_tools`** / **PyYAML`** (and forked Bandit/pip-audit) bumps to each repo’s **`scripts/refresh-pip-constraints.sh`**.
- **[`reusable-actionlint.yml`](.github/workflows/reusable-actionlint.yml)**: **PyYAML** via **`install-pyyaml-hashed`** instead of plain **`pip install`**.
- **Lockfile enforcement** in **`ci.yml`**: default **`pip-tools`** via **`install-pip-tools-hashed`**; non-default **`pip_tools_version`** still uses unhashed **`pip install`**.
- **Ruff** / **pytest** composites: default tool versions use **`pip --require-hashes`** when bundled constraint files exist.
- **README:** **Supported runners** (**linux/amd64**, **`jq`**, **actionlint** asset), **public repos / fork PRs** (secrets, minutes, cache), and **opinionated inputs** (extend via fork or extra **`workflow_call`** inputs) documented for operators.
- **Gitleaks first:** **`gitleaks-scan`** has **no** upstream **`needs`** — it runs **in parallel with Ruff** and **before pytest**. **`pytest-test`** **`needs`** **`ruff-lint`** and **`gitleaks-scan`**. **Trivy repo**, **Bandit**, and **pip-audit** **`needs`** **Ruff**, **Gitleaks**, and **pytest** (then run **in parallel**). README recommends **pre-commit** for **Ruff** + **Gitleaks** locally.
- **`docker-build`** **`needs`** **`bandit-scan`** and **`pip-audit-scan`** as well, with **`if:`** rules that treat **`skipped`** as OK **only** when **`run_bandit`** / **`run_pip_audit_scan`** are **false** (so a failed SAST/SCA still blocks the image). **`gitleaks`** / **`trivy`** use the same explicit pattern for their toggles.
- Reusable **[`dependency-review.yml`](.github/workflows/dependency-review.yml)**: removed **`concurrency`** so PR runs do not deadlock when the **caller** workflow uses the same workflow **name** and **concurrency** **group** (GitHub detects a lock between parent and **`workflow_call`**).
- **Trivy** job id **`trivy-scan` → `trivy-repo-scan`** (was fully parallel / no **`needs`**); **`needs`** evolve with the rest of **`ci.yml`** (see above).
- Default **`trivy_version`** **`0.69.3`** (upstream had no **`v0.65.0`** release; Trivy install was 404).
- **[`ci.yml`](.github/workflows/ci.yml)** nested **`thadiust/*`** actions use **`@main`** (**`secrets-gitleaks`**, **`sast-bandit`**, **`pip-audit-scan-action`**) while this branch tracks floating solo-dev refs; switch to semver tags when you want reproducible pins.

### Added

- **[`dogfood-ci.yml`](.github/workflows/dogfood-ci.yml)** integration run of full **`ci.yml`** against **[`dogfood/`](dogfood/)**; **[`scheduled-security-scan.yml`](.github/workflows/scheduled-security-scan.yml)** weekly **`workflow_dispatch`** / cron. **[`ORG_PORTABILITY.md`](ORG_PORTABILITY.md)** (replace **`thadiust/…`**), **[`SECURITY.md`](SECURITY.md)** (disclosure policy).
- Hash-pinned installs: **[`install-pyyaml-hashed`](.github/actions/install-pyyaml-hashed/action.yml)** (**PyYAML** for actionlint), **[`install-pip-tools-hashed`](.github/actions/install-pip-tools-hashed/action.yml)** (default **`pip-tools==7.5.3`** lockfile step), **`constraints/`** under **[`ruff`](.github/actions/ruff/constraints/)** and **[`pytest`](.github/actions/pytest/constraints/)** composites; **[`scripts/refresh-pip-constraints.sh`](scripts/refresh-pip-constraints.sh)** to regenerate after version bumps.
- **`workflow_call`** inputs **`gitleaks_version`**, **`bandit_version`**, **`bandit_targets`**, **`pip_audit_version`**, **`run_runner_info`**.
- **`trivy-repo-scan`** (replaces the old isolated **`trivy-scan`** job): uses **`thadiust/trivy-scan@main`** (**`scan_kind: filesystem`**) and SARIF category **`trivy`**.
- Optional **Docker** branch: **`docker-build`** waits on **Ruff**, **Gitleaks**, **pytest**, **Trivy repo**, **Bandit**, and **pip-audit**, then saves the image tarball; leaf **`trivy-image-scan`** loads it and runs **`trivy image`** (**SARIF** category **`trivy-image`**). Inputs: **`run_docker_build`**, **`dockerfile`**, **`docker_context`**, **`docker_image_tag`**, **`run_trivy_image_scan`**, **`trivy_image_fail_on_findings`** (default **true**, same strictness as repo Trivy; callers may set **false** with an explicit policy note if base-image noise is unacceptable for merges).
- **`concurrency`** on **[`actionlint.yml`](.github/workflows/actionlint.yml)** (cancel in-progress per ref).

### Removed

- **`.github/actionlint.yaml`** ignore for **`thadiust/trivy-scan`** now that the action repository is published.

## [1.0.8] — 2026-04-09

### Added

- Reusable **[`dependency-review.yml`](.github/workflows/dependency-review.yml)** (`workflow_call`) wrapping **`actions/dependency-review-action@v4`** for PR-time dependency admission control.

### Changed

- **[`reusable-actionlint.yml`](.github/workflows/reusable-actionlint.yml)**: verify **actionlint** tarball **SHA256** against upstream **`actionlint_${version}_checksums.txt`**; install to **`$HOME/.local/bin`** (no **`sudo`**); pin **`pyyaml==6.0.3`** for YAML parse steps.
- Nested composite pins in **[`ci.yml`](.github/workflows/ci.yml)**: **`thadiust/secrets-gitleaks@v1.0.3`**, **`thadiust/sast-bandit@v1.0.2`**, **`thadiust/pip-audit-scan-action@v1.0.1`**.

## [1.0.7] — 2026-04-06

### Added

- **Reusable workflow** [`.github/workflows/reusable-actionlint.yml`](.github/workflows/reusable-actionlint.yml): shared **actionlint** + optional **PyYAML** parse for composite actions or root `action.yml`. Other repositories can call `uses: thadiust/workflow-python/.github/workflows/reusable-actionlint.yml@v1.0.7`.
- This **CHANGELOG**.

## [1.0.6] — 2026-04-06

### Added

- Optional **`enforce_pip_tools_lockfile`**, **`pip_tools_requirements_in`**, **`pip_tools_version`**: run **pip-compile** against the committed lock (`requirements_file`) using the workflow **`python_version`**, then **`git diff --exit-code`** so drift fails CI.

### Fixed

- Lock enforcement uses **`actions/setup-python`** with **`python_version`** so **pip-compile** matches CI (not the runner default Python).

## [1.0.5] — 2026-04-06

### Added

- First release with **pip-tools** lockfile enforcement (superseded by **v1.0.6** for correct Python version during compile).

## [1.0.4] — 2026-04-06

### Added

- **`upload_code_scanning`** (default `true`): **Gitleaks** / **Bandit** SARIF upload via **`github/codeql-action/upload-sarif`** (categories `gitleaks`, `bandit`). Callers need **`permissions: security-events: write`**.

### Changed

- Nested pins: **`thadiust/secrets-gitleaks@v1.0.2`**, **`thadiust/sast-bandit@v1.0.1`**.

## [1.0.3] and earlier

See **git log** and tags on this repository for older snapshots.
