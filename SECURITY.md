# Security policy

## Supported versions

Security fixes are applied on the **`main`** branch and released as **semver tags** (**`v1.x.y`**) on this repository. Consumers should pin **`uses: …/ci.yml@v…`** (and matching nested action tags) for reproducible CI.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for undisclosed security problems.

- **Preferred:** Use [GitHub private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) for this repository if enabled.
- **Otherwise:** Contact the maintainers via a **private** channel (direct message or email) with enough detail to reproduce or assess impact.

Include: affected component (**`ci.yml`**, a composite under **`.github/actions/`**, or a referenced action repo), steps to reproduce, and impact (e.g. workflow injection, secret exposure, supply-chain concern).

## Scope notes

- This repository ships **GitHub Actions** workflows and composites; findings may also apply to **nested** actions (**`secrets-gitleaks`**, **`trivy-scan`**, **`sast-bandit`**, **`pip-audit-scan-action`**) referenced from **`ci.yml`** — please say which layer you believe is affected.
- **Fork PRs** and **public** repository behavior follow GitHub’s platform model; see the **[README](README.md)** sections on **public repositories** and **supported runners**.
- **CI threat posture** (untrusted PR code, hash coverage, Trivy policy, artifacts, Dependency Review): **[`CI_RISK_REGISTER.md`](CI_RISK_REGISTER.md)**. Workflows here avoid **`pull_request_target`** for running untrusted code with base-repo secrets; integration uses **`pull_request`**, **`workflow_call`**, and **`workflow_dispatch`** as documented in the README.
