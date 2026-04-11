# Adopting this workflow under another GitHub org

GitHub Actions **`uses:`** references must be **literal** strings. You cannot substitute `github.repository_owner` into `uses: owner/repo@ref`, so every **`thadiust/...`** path is a **fork-and-replace** (or **search-and-replace**) task when you vendor or republish under your company org.

## Strings to replace

After copying or forking **`workflow-python`**, replace at least:

| From | To (example) |
|------|----------------|
| `thadiust/workflow-python` | `myorg/workflow-python` |
| `thadiust/secrets-gitleaks` | `myorg/secrets-gitleaks` (or your mirror) |
| `thadiust/trivy-scan` | `myorg/trivy-scan` |
| `thadiust/sast-bandit` | `myorg/sast-bandit` |
| `thadiust/pip-audit-scan-action` | `myorg/pip-audit-scan-action` |

Search paths:

- `.github/workflows/ci.yml`
- `.github/workflows/reusable-actionlint.yml` (header comment + **`install-pyyaml-hashed`** **`uses:`**)
- **`README.md`**, **`CHANGELOG.md`**, composite **`README.md`** files under **`.github/actions/`**

Consumer app workflows that call **`uses: thadiust/workflow-python/.github/workflows/ci.yml@…`** must point at **your** org (or an internal registry mirror you control).

## Nested actions in this repo

These live under **`.github/actions/`** and are referenced from **`ci.yml`** with **`thadiust/workflow-python/.github/actions/...`** so reusable workflows resolve correctly from **caller** checkouts. When you republish, keep that pattern with **your** org prefix.

Hash-pinned Python installs (**`ruff`**, **`pytest`**, **`pip-tools`**, **`PyYAML`**) use constraint files **inside** those action bundles; they move with the fork.

## Release hygiene

After mechanical replace, run **[`scripts/refresh-pip-constraints.sh`](scripts/refresh-pip-constraints.sh)** whenever you bump default tool versions, then commit the updated **`constraints*.txt`** files.
