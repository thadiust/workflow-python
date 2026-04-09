# Changelog

All notable changes to **workflow-python** are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [semantic versioning](https://semver.org/) for tags (`v1.x.y`).

## [Unreleased]

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
