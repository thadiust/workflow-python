# Company rollout runbook (`workflow-python`)

**Audience:** Security / platform engineers onboarding **many** app repos onto this stack. **Severity scale:** **10** = dominant org risk or failed rollout; **0** = polish. This is **not** CVSS.

Enforcement lives in **caller** repositories (branch protection, environments, workflow choice). This library documents **defaults** and **options**; orgs **encode policy** in their own **`pull_request`** workflows and settings.

---

## 8 — Untrusted PRs: `pip install` + optional Docker

**Risk:** The **pytest** composite runs **`pip install -U pip`** and **`pip install -r`** on the **PR checkout**. Optional **`docker-build`** runs **`docker build`** from that tree. That is **normal** CI — and the **top organizational risk** for **public** repos or **mixed-trust** contributors: **arbitrary** dependency and Dockerfile steps run with **workflow permissions**.

**Caller / org checklist**

| Control | Purpose |
|---------|---------|
| **Fork policy** | Decide who can open PRs, auto-run vs manual approval for first-time contributors. |
| **Label-gated workflows** | Run full pipeline only after **`ok-to-test`** (or similar) from a maintainer — reduces drive-by abuse of minutes. |
| **GitHub Environments** | Require **reviewers** before jobs that build images, upload artifacts, or use elevated secrets. |
| **Fork PRs + Docker** | Decide whether **`run_docker_build`** is **`true`** for forks; default **`false`** avoids image builds on untrusted trees. |
| **Artifacts** | Align **who can read workflow artifacts** with org policy; image tarballs use **short retention** but are still downloadable for that window. |
| **Never** combine this with **unsafe** patterns | Do **not** use **`pull_request_target`** to run **untrusted** checkout code with **base-repo secrets**. This repo’s workflows avoid **`pull_request_target`** for that reason (see **[`SECURITY.md`](SECURITY.md)**). |

**Reference:** **[`CI_RISK_REGISTER.md`](CI_RISK_REGISTER.md)** §8, **[`README.md`](README.md)** (fork PRs, tokens, DAG).

---

## 7 — Trivy: unfixed CVEs hidden by default

**Default:** **`trivy_ignore_unfixed: true`** in **`ci.yml`** and **`trivy-scan`** — unfixed issues do **not** fail the gate.

**Org options**

1. Set **`trivy_ignore_unfixed: false`** on the **`ci.yml`** call for **stricter** visibility.
2. Keep default for **merge velocity** and rely on **[`scheduled-trivy-unfixed-report.yml`](.github/workflows/scheduled-trivy-unfixed-report.yml)** in **`workflow-python`** (**dogfood** scan, **report-only**) — enable **Actions → Scheduled workflows** in repo settings if GitHub requires it — or add a **second** caller workflow in app repos: **report-only**, **`fail_on_findings: false`**, **`ignore_unfixed: false`**.

---

## 7 — Application `pip install -r` integrity

**Default:** Only the **pytest** *tool* wheel set uses **`--require-hashes`** when constraints exist; **app** **`requirements.txt`** is a normal **`pip install -r`** unless the file contains **PEP 503** hashes.

**Org path**

1. **`enforce_pip_tools_lockfile: true`** + committed **`pip-compile`** lock (reproducible graph).
2. Optional **`pip-compile --generate-hashes`** + **`pytest_app_require_hashes: true`** on **`ci.yml`** (opt-in **`--require-hashes`** for the app install in the pytest composite).

---

## 6 — Dependency Review + main DAG

**[`dependency-review.yml`](.github/workflows/dependency-review.yml)** is **not** inside **`ci.yml`**.

**Default onboarding:** Call **[`python-pr-suite.yml`](.github/workflows/python-pr-suite.yml)** from a **`pull_request`** workflow (runs **Dependency Review** ∥ **`ci.yml`**; optional **`with:`** forwards lockfile / Docker / Trivy-image inputs — see workflow file — with other **`ci.yml`** inputs left at defaults), or copy **[`examples/consumer-pull-request-ci.yml`](examples/consumer-pull-request-ci.yml)**.

---

## 6 — SAST depth (Bandit only)

**Bandit** covers **Python pattern** issues; it is **not** full **semantic** SAST. Regulated or **AppSec-heavy** programs should **plan** **CodeQL**, **SonarQube** / **SonarCloud**, or another analyzer **in addition** — not as a replacement for this pipeline’s fast gates.

---

## 5 — Docker artifact exposure

**Short retention** on the image tarball reduces but does not remove risk. **Document** fork PR behavior and **artifact read** permissions (GitHub org / repo settings).

---

## 5 — `pip_tools_version` vs hashed **pip-tools**

**Hashed** install only for **`7.5.3`**. For enterprise strictness, set **`pip_tools_require_hashed_install: true`** on **`ci.yml`** when **`enforce_pip_tools_lockfile: true`** — CI **fails** if **`pip_tools_version`** is not **`7.5.3`** until you extend **[`install-pip-tools-hashed`](.github/actions/install-pip-tools-hashed/)** for another version.

---

## 4 — Bandit / pip-audit constraint files

Nested actions **warn** if the constraints file for the requested version is missing. **`sast-bandit`** and **`pip-audit-scan-action`** run a **verify** job in CI so the **default** version always has a matching **`constraints/*.txt`** (belt-and-suspenders after bumps).

---

## 3 — Sample Dockerfile

**[`sample-python-app`](https://github.com/thadiust/sample-python-app)** Dockerfile is **demo-only**; see its README and file header — **not** a production pattern.

---

## 3 — `secrets: inherit` (dogfood / scheduled)

**[`dogfood-ci.yml`](.github/workflows/dogfood-ci.yml)** and **[`scheduled-security-scan.yml`](.github/workflows/scheduled-security-scan.yml)** omit **`secrets: inherit`** when no secrets are required — prefer **explicit** **`secrets:`** when you add org secrets later.

---

## 2 — Platform checklist (runners)

| Requirement | Notes |
|-------------|--------|
| **OS / arch** | **linux/amd64** (e.g. **`ubuntu-latest`**). |
| **`jq`** | On **`PATH`** for **Gitleaks** / **Trivy** JSON parsing in nested actions. |
| **actionlint** | **reusable-actionlint** fetches **linux_amd64** only. |
| **Not supported without changes** | **ARM** runners; **minimal** images without **`jq`**. |

At scale, set **`run_runner_info: false`** on **`ci.yml`** to drop the diagnostics job.

---

## 2 — pip-audit double invocation

When **`format` ≠ `json`**, **pip-audit** runs **twice** (JSON for counts, then the requested format). Cost/latency only; optional optimization later — see **`pip-audit-scan-action`** README.

---

## Residual gaps (not oversights)

The items below stay **open** until **product** or **org** choices change — they are not unfinished YAML polish inside **`workflow-python`** alone:

| Sev | Topic | Why it remains |
|-----|--------|----------------|
| **8** | Untrusted PR **`pip install` / Docker | Standard CI **runs** contributor code; mitigation is **caller** policy (labels, environments, fork rules). |
| **7** | **`trivy_ignore_unfixed`** on main gate | **Deliberate** default for merge velocity; strict programs set **`false`** or rely on **scheduled** unfixed visibility. |
| **7** | App **`--require-hashes`** | **`pytest_app_require_hashes`** defaults **off**; auditors drive **org default** + hash-mode lockfiles. |
| **6** | SAST depth | **Bandit**-centric by design; **CodeQL** / **Sonar** are **additional** products. |
| **5** | **`python-pr-suite`** surface | Forwards a **wide** set of **`ci.yml`** inputs; exotic knobs still need a **two-job** caller or suite PR. |
| **5** | Docker artifacts / fork ACLs | **Org** settings and **caller** workflow choice. |
| **4** | No Dependency Review on **push** | **GitHub** model: DR is **PR**-oriented; add a separate policy for **default branch** if required. |

---

## Related

- **[`CI_RISK_REGISTER.md`](CI_RISK_REGISTER.md)** — detailed risk list + positive findings.
- **[`README.md`](README.md)** — inputs, DAG, consumer examples.
- **[`MAINTAINERS.md`](MAINTAINERS.md)** — version bumps and constraints.
