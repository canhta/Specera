# Security — adversarial review

Red team against [`product-concepts.md`](product-concepts.md) and the stage model in [`sdlc-model.md`](sdlc-model.md). Competitor detail is linked, not repeated. Labels per [`plan.md`](plan.md).

**Why this threat model differs from a code-search tool's.** Specera does not emit advice; it emits an artifact that closes a gate and may be shown to an auditor. Every incumbent in [`comparison.md`](comparison.md) §2 Gap 4 is advisory — Duo "never sets the Approve state", Copilot "will not block merging". Advisory output is worth attacking for nuisance. Gate-closing, audit-facing output is worth attacking for money, schedule and liability, so the adversary is not an outside researcher but **the developer whose PR is blocked, the contractor paid by story, and the insider who needs a release to have looked compliant**.

## 0. Two asymmetries that organise everything below

`INFERENCE` (design). Nearly every attack here reduces to one of two questions; getting them right is worth more than every control listed afterwards.

**A — base or head?** Anything read from the PR head is authored by the party being judged. A rule evaluated from the base cannot be edited by the change it governs; a rule evaluated from the head can be deleted in the commit that violates it. This alone separates Concept 2 from Concept 3 (§8).

**B — trusted builder, or a job the branch defines?** On GitHub a `pull_request` workflow runs the workflow file *from the branch*. Anyone who can edit `.github/workflows/*` in their own PR can make CI emit any JUnit XML without running a test. `FACT` This is why SLSA separates builder identity from build definition and why GitHub's OIDC token carries `job_workflow_ref`. Signing an artifact produced by an untrusted job signs a lie faithfully.

---

## 1. Prompt injection via ingested content

**Attack.** A repo, dependency, PR description, commit message, Jira ticket or code comment carries instructions addressed to Specera's agent. Open-source contributions, contractors and compromised accounts all put attacker text on the ingestion path. **Cost: one PR or one Jira comment. Zero infrastructure; on a public repo, no account trust at all.**

**Why it works — first-hand, not hypothesis.** `FACT` [`../../.spike/findings-supply-chain.md`](../../.spike/findings-supply-chain.md): cloning 19 competitor repos caused this spike's own coordinating agent to surface three skills from `repomix/.claude/skills/` as invocable capabilities. No file was read, approved or trusted — *placing the repos on disk was sufficient*. `FACT` 10 of 19 repos ship agent-directive files; GitNexus ships 48. `FACT` `GitNexus/.mcp.json` declares `npx -y gitnexus@latest mcp` — unpinned, no integrity check, fetched and executed at run time — beside a checked-in `settings.local.json` setting `enableAllProjectMcpServers: true` and pre-allowing `Bash(npx gitnexus *)`, `Bash(gh pr *)`, `WebSearch`. **A permission allowlist that arrives by `git clone` is a privilege-escalation primitive.**

`INFERENCE` The precedent holds elsewhere: [potpie](competitors/potpie.md) §6 gives its reconciliation agent a write tool over durable graph memory while reading untrusted PR and issue text — a direct path from a malicious comment to poisoned project memory later agents treat as authoritative. [DeepWiki/Devin](competitors/services/deepwiki-devin.md) §6 ingests `AGENTS.md` as *instructions*, so a PR editing `AGENTS.md` injects into the reviewer of that same PR (asymmetry A, failed).

**Mitigation.** (1) **Analysing a repo must never mean adopting its instructions** — `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.mcp.json`, `.claude/**`, `settings.local.json` and successors are inert data on a fixed handling path; an explicit, tested deny-list in the harness, not a property of the prompt. (2) Repo content enters context only inside a delimited untrusted region, and every claim derived from it is written `inferred`/`hypothesized`, never `deterministic`/`attested`. (3) **No model output may set a gate conclusion** — C1 states this for blue/red-team plans; it must extend to the impact set and every passport field. (4) During ingestion: no network, no write tools, no cross-repo read.

**Residual.** High and permanent. Injection *steers* rather than forges: it can suppress an impact-set entry, poison a durable `inferred` claim a human later trusts, or bias a challenge into silence. Controls (2)–(4) cap damage at "the advisory half was wrong". `INFERENCE` **No content-level filter should be counted on.** Any defence reading "the model will notice the instruction is hostile" or "a reviewer will see the odd suggestion" is not a mitigation — restate it as accepted risk. Only capability limits are load-bearing.

---

## 2. Forged evidence

The most important section. If the artifact gates a merge and supports an audit, it is the target.

### 2.1 Forgery at the source — the untrusted producer

**Attack.** A developer edits `.github/workflows/*` (or `conftest.py`, or adds a pytest plugin) in their own PR so CI emits JUnit XML reporting everything passed, having run nothing. The collector ingests it, signs the ledger row, posts a green check. **Cost: ~10 lines, no privilege beyond opening a PR on a branch they already have.**

**Why it works.** Asymmetry B. Signing does not help — the signature is valid and the artifact is true about what it says (a file said this) and false about what a reader believes.

**Mitigation, structural and not free.** Accept attestations only from a **trusted builder**: an org-owned pinned reusable workflow, with the OIDC token's `job_workflow_ref` verified against an allowlist Specera holds outside the repo; reject non-matching attestations rather than downgrade them. The alternative — Specera runs the checks itself — trades this for sandbox, egress and credential custody risk (§5). Pinning moves C3's onboarding from "add an annotation" to "adopt an org-level workflow": a real adoption cost that must be priced, not assumed.

**Residual — irreducible.** The *test code* is still head-branch authored. A trusted builder proves a specific runner executed a specific command over a specific tree and exited 0; it cannot prove what the code did. `conftest.py` can monkeypatch assertions; a plugin can rewrite outcomes. **Specera can prove the provenance of an execution; it cannot prove the semantics of the code executed.** Anyone who can merge to base can also change the pinned workflow.

### 2.2 Semantic forgery — the annotation says what its author wants

**Attack.** C3's binding is `@covers FUT-803.AC2` on a test. A developer under schedule pressure writes `def test_ac2(): assert True`, annotates it, and the gate goes green with a fully valid, signed, reproducible ledger row. **Cost: negative — cheaper than doing the work.**

**Why it works.** The binding is an assertion by the audited party about their own work, verified by nothing. Cryptography is orthogonal: it makes the false claim non-repudiable, not detectable.

**Mitigation.** None prevents it. What exists: **split the claim** into an *execution attestation* (strong — builder identity, tree digest, command, exit code, run URL) and a *coverage assertion* (weak — who wrote the annotation, in which commit, approved by whom), never rendered as one verdict; make the annotation diff first-class evidence so the ledger answers "who asserted this" without pretending to answer "is it true"; add cheap deterministic flags that need no model — a bound test touching no file the PR changed, a bound test with no assertions, a bound test below a runtime floor — as *flags on the artifact*, not gates; CODEOWNERS on the annotation surface if the customer wants it.

**Residual: complete, against a motivated insider.** `INFERENCE` This must constrain the product's **claim**, not only its design. "Proof to an auditor that this requirement was tested" is unsupportable. "A tamper-evident, non-repudiable record of who asserted coverage and which execution backed it" is supportable — and still strictly better than Xray/Zephyr, which store a manually asserted link with no execution at all. Marketing the former sells an audit-fraud instrument.

### 2.3 Replay onto a different commit

**Attack.** Pass on head SHA `X`; base moves; the squash or merge produces `Y` whose tree differs. The artifact attests `X`, what ships is `Y`. **Cost: zero, and usually accidental — which is what makes it dangerous, since the failure looks like normal operation.**

**Why it works.** GitHub re-runs checks against a moved base only if *"require branches to be up to date"* is on, which orgs disable because it serialises merges. In the audit direction, after a squash `X` is not in mainline history and survives only as `refs/pull/N/head`.

**Mitigation.** SHA-keying ([`sdlc-model.md`](sdlc-model.md) §1) is necessary, not sufficient. Also: require up-to-date branches **or** re-attest the merge result and treat the merge commit as the audited artifact; assemble the release bundle only from commits reachable from the tag, refusing artifacts whose SHA is unreachable; verifier fails closed on unknown or unreachable SHAs rather than warning.

**Residual.** The release rule creates a new failure: after a squash *no* passport is reachable, so a correctly configured system reports "no evidence" for every squash-merging customer. Fixing that needs post-merge re-attestation, doubling check cost.

### 2.4 The gate itself is the weakest link

**Attack.** Compromise Specera's GitHub App, or be an employee with production access, and call the Checks API with `conclusion: success`. No evidence is forged; none is needed. **Cost: high (needs Specera compromise) — but the payoff is every customer at once and detection is near zero, because green is the expected state.**

**Why it works.** `FACT` A required status check trusts the API call that sets it, not any signature. **Signing is therefore decorative with respect to the gate** unless something the customer controls verifies it.

**Mitigation — structural, cheap, should be non-negotiable.** Specera produces the attestation; **the required check is a customer-side verifier** running in the customer's CI against a trust root the customer holds. Specera's own check becomes informational. This also removes Specera from the availability path (§7). `FACT` GitLab's external status checks offer the same shape natively with an HMAC shared secret ([gitlab-duo.md](competitors/services/gitlab-duo.md) §3) — but HMAC is *shared*: it authenticates the caller and gives the customer no independent verification path, so the argument stands there too.

**Residual.** The verifier's own config lives in the repo (asymmetry A) and must be base-branch-evaluated and CODEOWNER-protected. An attacker inside Specera can still *block* every merge (§7).

### 2.5 Keys, clocks, revocation

- **Key custody.** `INFERENCE` One Specera-held signing key means Specera can forge any customer's evidence and one compromise forges everyone's — an unsellable liability for an audit-grade product. Required: keyless per-workload identity (Fulcio-style certificate bound to the customer's CI OIDC identity) or a customer-held KMS key Specera never possesses. *Residual:* the CA and OIDC issuer become trusted third parties.
- **Clock trust.** A self-asserted timestamp lets an insider backdate evidence to before an incident. Required: RFC 3161 timestamping or transparency-log inclusion, which proves *existed-by-T* — exactly the anti-backdating property. *Residual:* a public log leaks artifact digests and repo identifiers; a Specera-hosted log returns trust to Specera and defeats the purpose.
- **The two controls above conflict, and the conflict is load-bearing.** `INFERENCE` (raised by the blue team, 2026-08-04) The keyless-identity fix in the previous bullet and the public-log fix in this one compose badly: a Fulcio-issued certificate embeds the CI OIDC subject, which for GitHub Actions contains the **repository path and workflow ref**. Publishing to a public Rekor instance therefore emits a continuous, timestamped public feed of a customer's *private* repository names, branch names, and build cadence — before any artifact digest is considered. For the regulated buyers who are the only plausible market for audit-grade evidence, that is disqualifying on its own. *Residual after mitigation:* the available options are a private transparency log (trust returns to Specera or to the customer, weakening third-party verifiability), redacted/pairwise-pseudonymous certificate subjects (loses the identity binding that made the signature meaningful), or customer-hosted logs (operational burden shifted to the buyer). **There is no option that is simultaneously publicly verifiable, non-repudiable, and confidential** — pick two, and say which two in the product spec rather than discovering it in a security review.
- **Revocation.** *Residual, plainly:* **revocation nobody checks is not revocation.** A superseded or repudiated attestation must fail closed in the verifier by default — design it to require a freshness proof, not to consult an optional list.

---

## 3. Excessive permissions

`INFERENCE` throughout; scopes from the vendor docs cited in the competitor files.

| Concept | GitHub | Jira | Note |
|---|---|---|---|
| C1 | `contents:read` **org-wide** (cross-repo impact), `checks:write`, `pull_requests:read`, Actions artifacts, plus deploy/observability | `read:jira-work`, `write:dev-info:jira` | Largest surface in the spike |
| C2 | `contents:read` on governed repos, `checks:write` | none | Smallest; can run as a CLI with no App at all |
| C3 | `checks:write`, `pull_requests:read`, optional `contents:read` | `read:jira-work` + **`write:jira-work`** for AC-id write-back | The Jira write is the escalation |

**Blast radius.** Installation tokens are short-lived; the **App private key is not, and it mints tokens for every installation**. One key compromise equals full source of every estate that granted org-wide `contents:read`. `FACT` Greptile's Jira grant reads "anything the Atlassian account that authorized the connection can see" ([greptile.md](competitors/services/greptile.md) §6) — broad grants are the category norm, so this is something to beat rather than match.

**`checks:write` is a production-control capability** — the ability to block or unblock every merge in the organisation. Procure, log and rotate it like a deploy credential, not a read scope. `FACT` GitHub's own agent requires being a branch-protection **bypass actor** ([github-copilot.md](competitors/services/github-copilot.md) §1), i.e. enabling it *weakens* the control set. Specera must never require a bypass actor.

**Least privilege.** C3's MVC needs no source access: annotations and JUnit XML are both already in the CI workspace. AC-id write-back is the only reason for `write:jira-work` — drop it in v1, keep ids repo-side, copy Greptile's "never writes to Jira" posture, and earn the scope later. C1's org-wide read cannot be reduced without abandoning cross-repository impact, which is its differentiator.

**Residual.** With per-installation short tokens, HSM custody, App IP allowlisting and no `contents:write`, a Specera compromise still yields read of all customer source and control of all merge gates. No configuration removes this for C1. For C2 and C3 one does: run inside customer CI and hold nothing.

---

## 4. Data leakage and tenancy

**Precedents that set the procurement bar.** `FACT` Greptile: no first-party no-training statement, and cloud code "cached until GitHub/GitLab access revocation" — a persistent copy of customer source in the vendor's AWS account ([greptile.md](competitors/services/greptile.md) §4, §6). `FACT` Devin: training on customer code is **default on** for free and paid, enterprise needs written consent, and there is no air-gapped option because the Brain never leaves Cognition ([deepwiki-devin.md](competitors/services/deepwiki-devin.md) §6). `FACT` Rovo: for non-Enterprise customers, requirement text and diff content leave the residency region at inference time ([atlassian-rovo.md](competitors/services/atlassian-rovo.md) §6).

**What Specera must commit to, and the cost.** No training on customer data, no toggle, stated first-party (cost: none technically; forfeits a data asset the category assumes). Ephemeral clones with explicit TTL rather than "cached until revocation" (cost: re-index latency and compute per run). Zero-retention inference with the provider named — `UNVERIFIED` whether ZDR terms compose with prompt-caching discounts on each provider; verify before pricing, as it changes unit economics on large diffs. Per-tenant encryption, no shared embedding or graph store (cost: kills cross-tenant retrieval efficiency; correct trade). A self-host / in-region SKU — `INFERENCE` C3's buyer is *specifically* the regulated one, so this is not optional for the concept most likely to sell (cost: a second distribution, an air-gapped build, no central telemetry or eval; Greptile pays it, Devin declines and cannot serve those buyers).

**Residual.** Test output is the leakiest artifact and the least examined — failing assertions routinely carry production-shaped fixtures, tokens and PII. The ledger is **append-only and retained beyond CI expiry by design** (C3 step 5), so a secret leaked into a JUnit message is retained *longer* than it would have been without Specera. Required: redaction on ingest, and a documented deletion path that can override append-only under legal instruction. State which wins.

---

## 5. Sandbox escape and egress

Applies only if Specera executes customer tests.

**Attack.** An outside contributor opens a PR; Specera runs the branch to produce evidence; the test code exfiltrates sandbox credentials or reaches the cloud metadata endpoint. **Cost: one drive-by PR.**

**Why it works.** `FACT` Greptile's TREX executes attacker-authored branch code in a rootless podman container with chmod, mount-namespace masking and chroot — a real, published control set — but no page addresses **network egress from that sandbox**, nor whether an open-source drive-by can trigger execution ([greptile.md](competitors/services/greptile.md) §4, §6). File containment without egress containment does not stop exfiltration.

**Mitigation.** Default-deny egress with an allowlist to a pinning package proxy; block the cloud metadata endpoint; no customer secrets in the sandbox; no execution for fork PRs or first-time contributors without maintainer approval; per-run ephemeral identity, no standing credentials.

**Residual — sharp and structural.** Real integration tests need network and credentials, so a no-secrets sandbox produces weaker evidence exactly where evidence matters, and a with-secrets sandbox puts production credentials inside a process running attacker code. `INFERENCE` The clean answer is **not to execute** — consume the customer's own CI results. That is Concept 3's design and it is a security advantage nobody has credited. C1's MVC as written ("run the repo's existing test and scan commands") is remote code execution from an untrusted repo placed in the *minimum viable core*; the `npx -y gitnexus@latest` case in [`../../.spike/findings-supply-chain.md`](../../.spike/findings-supply-chain.md) shows what "the repo's existing commands" resolves to in practice.

---

## 6. Specera's own supply chain

- **Parsers are the primary hostile-input surface.** serena's `solidlsp` drives real language servers; tree-sitter grammars are C. Both parse untrusted repo bytes in-process. *Mitigation:* a separate process, no network, no filesystem write, memory cap, timeout. *Residual:* a grammar crash is a DoS on the gate (§7).
- **The model provider is a trusted third party in C1's evidence chain** (impact set, challenges) and in **none** of C3's. That is a ranked difference in trusted-computing-base size, not a stylistic one.
- **Inherited agent-directive surface** (§1): the deny-list must be a tested property of the ingestion harness, re-tested as conventions appear — `FACT` five distinct conventions across 19 repos in one day.
- **Specera's own builds.** `INFERENCE` A company selling attestations that does not attest its own releases is unsellable to the buyer it targets. Pin dependencies by digest, SLSA-provenance its artifacts, publish for its own output the verification instructions it expects customers to run. *Residual:* a signed-but-malicious upstream release defeats pinning; needs a review lag or a vendored subset.

---

## 7. Availability and abuse

**Attack.** A vendor-owned required check is a denial-of-service target against the customer's own delivery: take Specera down — or just be Specera on a bad day — and nobody in the organisation can merge. **Cost: low if the gate calls out per PR; near zero from inside Specera.**

**Why it works.** Fail-closed is the only setting that makes the gate meaningful and the only setting that turns a vendor outage into a company-wide freeze. Fail-open is worse: an attacker who wants to bypass the gate simply DoSes Specera.

**Mitigation.** The §2.4 restructure fixes most of it — with a customer-side verifier over a signed artifact, Specera's availability affects *artifact production*, not merge capability, and a cached valid artifact still verifies. Plus a documented, time-boxed break-glass that **emits its own evidence record**; `FACT` GitLab already does this — bypasses generate audit events ([gitlab-duo.md](competitors/services/gitlab-duo.md) §2). Abuse control: per-repo credit/rate limits (Greptile's credit metering doubles as one) and no execution for unapproved fork PRs.

**Residual.** Break-glass becomes routine under deadline pressure and the gate degrades to advisory — the exact failure the product exists to fix. The only counter is measuring break-glass rate as a product metric and showing it to the buyer, which is a procedural control and should be labelled one.

---

## 8. Which concept is most and least defensible

`INFERENCE` throughout.

**Most defensible: Concept 2 — Executable Architecture.** Not the best business; the only one where both §0 asymmetries fall the right way. Its rule lives in `docs/adr/**` and can be evaluated **from the base branch**, so a PR cannot delete the constraint that convicts it — and CODEOWNERS on that path is a native GitHub control, not a procedure. No tracker credentials, no customer code executed, no source egress (it can run as a CLI in customer CI), no model in the enforcement path. Decisively: **its evidence is re-derivable by anyone from the repo alone** — ADR, constraint and query are all in git — so verification does not require trusting Specera's signature at all. That is the strongest security property available here, and neither other concept has it.

**Least defensible: Concept 1 — Continuous Change Assurance.** Org-wide `contents:read` plus `checks:write` plus test execution plus a durable graph carrying model-written claims. Every threat above applies, and two apply only to it: graph poisoning via injected `inferred` claims (potpie's demonstrated shape) and RCE-by-design in its MVC (§5). Its one genuinely good security decision is already in the design — model output is `hypothesized` and never gate-blocking — and that structural containment is worth keeping wherever C1's ideas end up.

**Concept 3 — the honest mixed verdict.** No model verdict in the core loop is a real structural win: it removes the entire injection-to-verdict path (§1), needs no code egress, executes nothing, and has the smallest trusted computing base of the three. It does **not** make the evidence trustworthy, because both inputs — annotation and test — are head-branch-authored by the audited party (§2.1, §2.2), and unlike C2 they *cannot* move to the base, since the whole point is that the PR adds the test. C3 therefore has the best confidentiality posture and the worst insider-forgery posture. Both are true, and the second must ship written down.

**Structural vs procedural, explicitly.** Structural (survives a careless human): base-branch evaluation, customer-side gate verification, `job_workflow_ref` pinning, ingestion capability limits, no-model-in-verdict, default-deny egress, running in customer CI and holding nothing. Procedural (does not): reviewing annotation diffs, noticing an odd suggestion, honouring break-glass policy, reading a warning label on a low-confidence edge. Everything in the second list should score zero.

---

## 9. Findings that must constrain or kill

1. **Mandatory design change, not a kill: the merge gate must not be a Specera API call.** If it is, the signing, key-custody and transparency machinery is decorative with respect to the only thing that matters — whether the merge is allowed (§2.4). Ship a customer-side verifier as the required check, or drop the evidence claim.
2. **Scope change, not a kill: evidence produced by a branch-defined CI job is forgeable for ~10 lines of YAML** (§2.1). Trusted-builder pinning is the fix and it materially raises C3's onboarding cost. C3's "buildable in weeks" MVC does not include it and must be re-costed.
3. **A kill for one claim, not for a concept: no design in this spike can prove that a passing test exercises the criterion it claims to cover** (§2.2). The forgery is cheaper than compliance and invisible to cryptography. Specera may sell *tamper-evident, non-repudiable, execution-backed attribution*; it may not sell *proof that the requirement was tested*. **If the go decision rests on the second framing, the answer on that framing is no-go.**
4. **Remove "run the repo's existing test and scan commands" from C1's minimum viable core, or reclassify the MVC as executing untrusted code** (§5). As written it is RCE from an untrusted repo in the smallest shippable version.
5. **A single Specera-held signing key is disqualifying for the audit buyer** (§2.5). Keyless per-workload identity or customer-held KMS from v1, or the concept cannot be sold to the only buyer with a budget line.

`INFERENCE` None is a spike-level no-go alone. Item 3 is closest, and it is a no-go against a *claim* rather than a mechanism — which is why it must reach [`evaluation.md`](evaluation.md) before any positioning is written, not after.
