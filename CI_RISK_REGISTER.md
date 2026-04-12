# CI risk register (`workflow-python`)

**Scale:** **10** = immediate exploit or guaranteed compliance failure; **0** = polish / awareness. Numbers are **not** CVSS — they express **dominant CI risk** and **org onboarding** impact for this design.

This file complements **[`README.md`](README.md)** (behavior, inputs) and **[`SECURITY.md`](SECURITY.md)** (reporting). **Mitigations** for fork/untrusted PRs are mostly **process and caller workflow design** (labels, environments, path filters, restricted workflows), not something this repo can remove without changing the product.

---

## 8 — Untrusted code execution on every CI run (fork / malicious PR)

**What runs:** The **pytest** composite runs **`pip install -U pip`** then **`pip install -r`** against **`requirements_file`** from the **checked-out** tree. Optional **`docker-build`** runs **`docker build`** using **`Dockerfile`** (and context) from the same tree. That matches **standard** GitHub Actions for app CI: **arbitrary packages** and **image build steps** execute with **workflow permissions**.

**Why it matters:** For **public** repos, **fork PRs** execute this logic with a **restricted** token; **secrets** are not injected by default — but **minutes**, **cache**, and **workflow logic** still apply. The dominant **org-wide** risk is **trust boundaries** (who can open PRs, what runs automatically).

**Mitigations (caller / org):** Restricted workflows for forks, **required labels** before heavy jobs, **environment** gates with required reviewers, **path filters**, separate workflows for **trusted** vs **untrusted** contributors. **Do not** use **`pull_request_target`** to run untrusted code with base-repo secrets — this repo’s workflows use **`pull_request`** / **`workflow_call`** / **`workflow_dispatch`** only (**no** **`pull_request_target`** in this tree).

**Tokens / scopes:** See **[`README.md`](README.md) → Security and cost** (`permissions`, **`persist-credentials: false`**, artifact retention). For a **company** rollout, maintain a short **runbook**: which events fire (**`pull_request`** vs scheduled vs **`workflow_dispatch`**), which **`GITHUB_TOKEN`** scopes apply, and whether **fork PRs** build images or download artifacts.

---

## 7 — `thadiust/*` namespaces in `uses:` (org portability)

**Solo / single publisher:** **`ci.yml`** references **first-party** actions under **`thadiust/`** — expected when one maintainer owns the stack. **No** change recommended while that stays true.

**Company / internal org:** Replacing **`thadiust/…`** everywhere is mechanical; see **[`ORG_PORTABILITY.md`](ORG_PORTABILITY.md)**.

---

## 6 — Application dependencies installed without hash verification (pytest job)

**What:** Only the **pytest** **wheel set** uses **`pip --require-hashes`** when a matching **`constraints/pytest-*.txt`** exists. **`pip install -r requirements.txt`** for the **app** graph is a normal **pinned** lock unless the file includes **PEP 503** hashes — typical **`pip-compile`** output **without** **`--generate-hashes`** is **not** hash-verified at install time.

**Implication:** Integrity story is **“pytest tool install is hashed (when constraints match); app deps follow pip’s usual trust model.”**

**Hardening options:** Document that callers who need **`--require-hashes`** for the app must supply a **hash-mode** lockfile (or extend the composite with an input to pass **`--require-hashes`** / a dedicated constraints file — heavier).

---

## 6 — `trivy_ignore_unfixed` default `true` (policy)

**What:** **Unfixed** CVEs are **omitted** from the Trivy **fail** gate by default — favors **merge velocity** over **visibility** on unfixable issues.

**Org choice:** Set **`trivy_ignore_unfixed: false`**, or add a **second** **report-only** Trivy workflow, if the security program wants **unfixed** issues visible in the gate.

---

## 5 — Custom `pip_tools_version` bypasses hashed `pip-tools` install

**What:** **[`install-pip-tools-hashed`](.github/actions/install-pip-tools-hashed/action.yml)** runs **`--require-hashes`** only when **`pip_tools_version`** is **exactly `7.5.3`** (matching **`constraints.txt`**). Any other version uses **plain** **`pip install pip-tools==…`**.

**Mitigation:** Stay on **7.5.3**, run **`scripts/refresh-pip-constraints.sh`** after extending support for another version, or **accept** unhashed **pip-tools** for that step. See **[`MAINTAINERS.md`](MAINTAINERS.md)**.

---

## 4 — Bandit / pip-audit fallback when constraint file missing

**What:** Nested actions **warn** and install **without** **`--require-hashes`** if the expected **`constraints/*.txt`** is absent for the requested version. The **direct** tool version is still pinned; **transitive** integrity is weaker.

**Mitigation:** After version bumps, run each repo’s **`scripts/refresh-pip-constraints.sh`** and commit constraints — **[`MAINTAINERS.md`](MAINTAINERS.md)**.

---

## 4 — `bandit[sarif]` and hashed installs: transitive supply chain

**What:** Even with **`--require-hashes`** on the **constraint** file, **transitive** wheels depend on how the lock was **generated**; **extras** (e.g. **`bandit[sarif]`**) can pull additional deps — standard **pip** behavior.

**Auditors:** May ask for **fully** locked tool envs (broader constraints / different generator). Often **acceptable** for many orgs.

---

## 4 — Docker build artifact path

**What:** **`docker-build`** uploads a **tarball** artifact (short **retention**, e.g. **1 day** in **`ci.yml`**). Anyone who can **read workflow artifacts** can download it for that window.

**Fork PRs:** Align **org policy**: whether **image builds** run for forks, and **who** may download artifacts.

---

## 4 — Runner and tool assumptions

**What:** **linux/amd64**-oriented composites; **`jq`** on **`PATH`** where scanners parse JSON; **actionlint** fetched for **linux_amd64** only.

**Impact:** **ARM** or **minimal** images fail or misbehave until actions or images are adjusted. See **[`README.md`](README.md) → Supported runners and tooling**.

---

## 3 — Dependency Review not in the main `ci.yml` DAG

**What:** **[`dependency-review.yml`](.github/workflows/dependency-review.yml)** is **`workflow_call`**-only — correct, but **easy to omit** when onboarding.

**Mitigation:** Add a **caller** workflow on **`pull_request`** that **`uses`** it (snippet in **[`README.md`](README.md)**).

---

## 3 — Sample / template Dockerfile (consumer repos)

**What:** Demo Dockerfiles may use **`pip install`** as **root** before **`USER`** — **copy-paste** risk for production.

**Mitigation:** Treat **`sample-python-app`** as **demo-only**; read its README **Dockerfile** note.

---

## 2 — `secrets: inherit` on reusable calls (dogfood / scheduled)

**What:** **[`dogfood-ci.yml`](.github/workflows/dogfood-ci.yml)** and **[`scheduled-security-scan.yml`](.github/workflows/scheduled-security-scan.yml)** use **`secrets: inherit`**. Harmless when **no** secrets exist; for **defense-in-depth**, prefer **explicit** **`secrets:`** or **omit** when unused.

---

## 0 — Polish

- **Org rename** (`thadiust` → elsewhere): **[`ORG_PORTABILITY.md`](ORG_PORTABILITY.md)** when you care.
- **Roadmap tools** (Grype, SBOM, Sonar, …): out of scope until you adopt them — see **[`MAINTAINERS.md`](MAINTAINERS.md)** severity **0**.

---

## Related docs

| Topic | Where |
|--------|--------|
| Fork PRs, token scope, artifacts, pip hash summary | **[`README.md`](README.md)** → **Security and cost** |
| Bump tool defaults → refresh constraints | **[`MAINTAINERS.md`](MAINTAINERS.md)** |
| Replace `thadiust/` owner | **[`ORG_PORTABILITY.md`](ORG_PORTABILITY.md)** |
| Vulnerability reporting | **[`SECURITY.md`](SECURITY.md)** |
| Workspace-level fork / tag notes | **[`../README.md`](../README.md)** (parent **security-pipeline** workspace) |
