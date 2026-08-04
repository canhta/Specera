# Blue team — the case for building, and how it would be built

Agent A2, round 1, 2026-08-04. Input: [`product-concepts.md`](product-concepts.md), [`sdlc-model.md`](sdlc-model.md), [`comparison.md`](comparison.md). Labels per [`plan.md`](plan.md). Where evidence is thin this says `UNVERIFIED` rather than filling the gap with confidence.

## 1. Recommendation

**Primary: Concept 3, Executable Acceptance Evidence.** I agree with [`product-concepts.md`](product-concepts.md)'s ranking and found nothing to overturn it. The deciding reason is not that C3 is the most exciting — it is that C3 is the only concept whose core loop contains **no model verdict**, and [`comparison.md`](comparison.md) §3 establishes with independent data that the category's defining weakness is model verdicts at ~33% precision. Everything else follows from refusing to inherit that number.

**Restated so it is not a wish:** Specera does not decide whether an acceptance criterion is met. It records *which named test, executed on which commit, in which CI run, with which artifact digest, was asserted to establish it*; signs that record with an identity the customer controls; and blocks the merge when the record is empty. The claim is custody of evidence, not judgement.

**One part borrowed from Concept 2, and only one.** The ledger key is a `criterionId`, and `criterionType` is a discriminated union whose phase-1 member is `jira-acceptance-criterion`. C2's ADR constraint becomes a *second member* later — same schema, signing, gate, storage, verify command. Marginal phase-1 cost: one enum field. `INFERENCE` Not scope creep, because phase 1 ships zero lines of constraint compiler, zero graph, zero `solidlsp`. It is a hedge on a shared spine: if Claim A fails, the criterion source moves from "mined from a tracker" to "authored in the repo" — C2's shape — without rewriting the artifact, the signing, or the gate. `UNVERIFIED` whether that pivot is commercially viable; C2's buyer-has-no-budget problem is real and I have no evidence against it.

**Concept 1 is rejected as a starting point, not as an end state.** The Change Passport is the right general artifact and the wrong first one. Its own falsification test — what fraction of fields a deterministic check fills — is one C3 passes trivially and C1 passes only after the graph works.

## 2. The claims that must be true

**Claim A — the substrate exists.** In a real Jira + GitHub estate, (a) a usefully large fraction of work items carry individually addressable acceptance criteria a deterministic parser can segment, and (b) a usefully large fraction of merged changes touch a test.

- `FACT` (first-hand, [`atlassian-rovo.md`](competitors/services/atlassian-rovo.md) §9) three of three sampled live Jira work items carried structured `## Acceptance Criteria` AC1–AC6 markdown. n=3 is an anecdote, not a rate.
- `FACT` (measured by me, 2026-08-04, `.spike/clones/`) over the 400 most recent non-merge commits touching source per repo, the share also touching a test path: graphify 89%, codegraph 89%, repomix 62%, serena 45%, codegraphcontext 45%, potpie 34%, gitdiagram 34%, aider 28%, deepwiki-open 3%. Median ≈45%. A merge-commit proxy over 10 repos gave median 38% and disagreed sharply on squash-merge repos (potpie 0% vs 34%) — that method is unreliable and I report both.
- `INFERENCE` These are young OSS infrastructure repos: an **optimistic** reference class for test discipline, by an amount I cannot quantify. The enterprise number is the one that matters and I do not have it.
- Threshold: (a) ≥40% parseable; (b) ≥35% of merged PRs touch tests. Below either, the product spends its life doing requirement cleanup.

**Claim B — someone already pays for a worse version of this.** A named existing budget line for requirement→test traceability exists, and what it buys is a **manually asserted** link with no execution proof. `UNVERIFIED`, and the single most important unchecked fact in this proposal. [`product-concepts.md`](product-concepts.md) names Xray and Zephyr Scale; nobody in this spike has read their pricing, install counts, or data model. Verified by: Marketplace listings and published schemas — specifically whether either stores a commit SHA and a run id against a requirement. If Claim B is false, this is a vitamin sold to people never asked for evidence, and no engineering rescues it.

**Claim C — the incumbents structurally cannot retain this.** Largely established: `FACT` Rovo's graph truncates status history at 90 days and its AC verdicts are PR comment prose; `FACT` GitLab's requirements report is `{"1":"passed"}` keyed by IID with `{"*":"passed"}` a legal wildcard, naming no test, commit, or assertion; `FACT` Copilot review "will not block merging". `INFERENCE` The honest form is **"they have not, and each has a specific commitment in the way"** — not "they cannot". See §10.

## 3. Architecture

**Integrate.** GitHub **Checks API** — `FACT` GitHub Apps only, `checks: write`; conclusions `success/failure/neutral/cancelled/skipped/timed_out/action_required`; a check run's `name` becomes selectable as a **required** status check once reported once; `output.annotations` capped at **50 per request**; `details_url` is a free integrator link. This is the gate slot Copilot deliberately leaves empty. Jira **Builds API** `POST /rest/builds/0.1/bulk` — `FACT` carries `url`, `pipelineId`, `references[]` (commit + ref) and a typed `testInfo {totalNumber, numberPassed, numberFailed, numberSkipped}`. **Correction to prior spike documents:** this, not devinfo, is the typed pass/fail surface in Jira — `FACT` devinfo `0.10/bulk` has repositories/commits/branches/pullRequests and **no test or evidence entity type**; its only usable evidence carrier is the per-entity `url`. Devinfo still carries the PR↔work-item edge and the evidence permalink. GitLab **external status checks** (HMAC, merge-blocking, Ultimate) give phase-2 gate parity. **Sigstore** + **in-toto Statement v1** for signing.

**Deferred, and honest about why.** **zoekt** (Apache-2.0): phase 1 finds annotations with `git grep`; zoekt earns its place only at monorepo/multi-repo scale. **serena `solidlsp`** (MIT, ~60 languages, `SolidLanguageServer.create` at `src/solidlsp/ls.py:450`): needed for annotation-drift detection and the C2 criterion type — not for phase 1.

**Borrow** (licences cleared in [`comparison.md`](comparison.md) §5). *potpie* (Apache-2.0), two specific things: `FACT` `EVIDENCE_STRENGTHS = ("deterministic","attested","inferred","hypothesized")` at `context-core/.../ontology.py:92`, and bitemporality — `valid_at`/`invalid_at` (event time) plus `created_at`/`expired_at` (system time), singleton supersession stamping `invalid_at`, at `context-engine/.../graph/cypher.py:523-557`. The ledger is append-only and bitemporal for the same reason: a binding is *superseded*, never updated. *codegraphcontext* (MIT): type-splitting applied to `bindingOrigin` — a model-suggested binding is a **different type**, not a boolean, so a query that forgets to filter gets the safe answer. *gitdiagram* (MIT): schema-constrained generation with no loose-parse fallback, applied to every LLM output. *aider* (Apache-2.0): repo-map ranking, advisory path only.

**Legally excluded:** GitNexus (PolyForm Noncommercial), sourcebot (FSL), stakgraph (no LICENSE), opengrok (CDDL). **Unavailable to everyone:** Atlassian Teamwork Graph API (EAP — no production deployment, no distribution).

**Build:** criterion parser and id write-back; source-annotation extractor (tree-sitter, per language); CI report collector and **test node-id canonicaliser**; append-only bitemporal ledger; signer; `specera verify` CLI; GitHub App; replay harness.

`UNVERIFIED` — the node-id canonicaliser is the sharpest unpriced engineering risk. pytest node ids and JUnit5 `classname`+`name` are derivable from source. **Jest/vitest node ids derive from `describe`/`it` string literals, computable at runtime**, so binding an annotation to a node id is not always statically decidable. `FACT` per-`<testcase>` `<properties>` — which would sidestep this — is supported by pytest, gotestsum and mocha-junit-reporter but **not** jest-junit (jest-community/jest-junit#135); JUnit5 emits `<system-out>` instead. There is no single carrier that works everywhere. Verified by the TypeScript half of E2 (§9).

## 4. The evidence artifact

**Evidence Statement**: in-toto Statement v1, `predicateType: https://specera.dev/AcceptanceEvidence/v1`, in a DSSE envelope. `subject[0].digest.gitCommit = <head SHA>`. One statement per `(repo, commit SHA, check run)`; each **ledger row inside it** keyed `(criterionId, testNodeId, commitSha, ciRunId)`.

```yaml
schemaVersion: "1.0.0"          # never renamed in a compliance path
producer:  {name, version, buildDigest}
scm:       {provider, repo, prNumber, headSha, baseSha, mergeSha?}
workItems: [{key, tracker, instanceId, resolvedAt,
             resolvedFrom: [branch|commitTrailer|prBody|api]}]   # every signal, not the first
criteria:
- id: "FUT-803.AC2"
  criterionType: jira-acceptance-criterion    # union; ADR constraint later
  textDigest: sha256(normalised text)         # detects post-hoc AC edits
  verdict: proved | unproved | unstable | waived | not-applicable
  bindings:
  - testNodeId: "tests/test_billing.py::TestInvoice::test_tax_rounding"
    bindingOrigin: human | model-suggested-human-approved | imported
    approvedBy: <scm identity>                # required unless human-authored
    annotation: {path, line, blobSha}         # the literal @covers, addressable
    outcome: passed | failed | skipped | error | absent
    runs: [{ciProvider, runId, runUrl, startedAt, durationMs, attempt,
            reportArtifactDigest: sha256, reportPath, runtimeImageDigest}]
    flakeWindow: {sameShaRuns, outcomeFlips}
  waiver?: {reason, approvedBy, approvedAt, expiresAt, ticket}
checks:   [{checkId, command, exitCode, artifactDigest, resultRef}]   # non-test checks
coverage: {total, proved, unproved, unstable, waived}
gate:     {conclusion, checkRunId, policyId, policyDigest}
```

**Signing.** Sigstore keyless: the signing identity is the **customer's CI workload OIDC identity** (e.g. the GitHub Actions token for `org/repo@ref`), certified by Fulcio, logged to Rekor. `INFERENCE` This is the load-bearing choice — the customer verifies without trusting Specera, and the record survives Specera's disappearance. A statement signed by *Specera's* server would be a vendor assertion, i.e. the thing we are criticising. Air-gapped fallback: Merkle-chained append-only log with checkpoints signed by a customer KMS key.

**Storage, three copies, deliberately.** (1) A git note under `refs/notes/specera-evidence` on the commit, so the record replicates with the repo. (2) A GitHub Release asset at release time, plus an OCI referrer on the built image. (3) Specera's Postgres ledger for query and rollup — **explicitly not the system of record**. The ledger retains the **JUnit report text itself**, not only its digest: GitHub Actions artifacts expire by default at 90 days, so a digest alone becomes unverifiable on exactly the timescale that defeated Rovo. Retention is customer-configured, default indefinite; deletion is a tombstone plus an audit event.

`UNVERIFIED`/security: Rekor is a **public** transparency log, and a Fulcio certificate carries the repository URL and workflow path. For private repos that is a real leak, so public Rekor must be opt-in, with a private Rekor instance or customer-KMS signing as the default for non-public code. Flagged for [`security.md`](security.md).

**How a human verifies one.** `specera verify --statement s.json --repo <url>`, with no network access to Specera: (1) verify the DSSE signature against the Fulcio cert and Rekor inclusion proof, asserting the cert identity is the expected repo and workflow; (2) assert `subject[0].digest.gitCommit` exists and is the commit audited; (3) per criterion, re-fetch the text, normalise, hash, compare to `textDigest` — a mismatch means the criterion was **edited after it was proved**, surfaced and never silently passed; (4) per binding, check out `annotation.blobSha` at `annotation.path` and confirm the annotation literally names the criterion id; (5) recompute the CI report's SHA-256 against `reportArtifactDigest`; (6) **replay** — re-run `testNodeId` at the recorded commit inside `runtimeImageDigest` and compare to `outcome`. Steps 1–5 need no test environment. Step 6 does, and is the weakest link: statements whose runtime image is unpinned are marked `replayable: false`.

## 5. The deterministic verification set

No model participates in any of these. Each is a named check with a stable id.

| Check | Mechanism |
|---|---|
| `specera/work-item-resolution` | Regex over branch name, commit trailers, PR title and body, plus explicit API links. Takes the **union** and records every signal, surfacing disagreement rather than resolving it silently — unlike Rovo, which takes one and aborts on ambiguity. A PR resolving to **no** work item returns `neutral`, not `failure`, unless policy demands linkage; blocking every chore PR is how this tool gets uninstalled in a week |
| `specera/criterion-schema` | Every criterion has a unique id, non-empty text, a stable `textDigest`. Purely structural; no judgement about "testability" |
| `specera/annotation-resolution` | Every `@covers KEY.ACn` in the repo resolves to a criterion that exists in the tracker. Dangling references fail |
| `specera/coverage-gate` | **The merge gate.** Every criterion on every linked work item has ≥1 binding with outcome `passed` at head SHA and a matching `reportArtifactDigest`. Posted as a check run conclusion; unproved criteria listed as annotations (≤50/request) |
| `specera/flake-guard` | A binding whose outcome flipped across runs **at the same SHA** is `unstable`; unstable proof does not count as proof. Pure ledger query |
| `specera/coverage-delta` | Set difference of proved criteria between base and head SHA. Catches proof silently lost |
| `specera/artifact-integrity` | Recompute report digests; verify DSSE + Rekor inclusion |
| `specera/policy-integrity` | The gate policy is a file in a protected path and its digest is in the statement, so changing policy and code in one PR is detectable and blocked by CODEOWNERS |
| `specera/scan-binding` | Ingest SARIF from CodeQL/semgrep, bind findings to the same SHA. **We run no scanner** — [`sdlc-model.md`](sdlc-model.md) §2 says do not build scanners; we bind someone else's deterministic output into the record |
| `specera/replay` | Out-of-band re-execution of a named test at a named SHA. Not a CI gate; the auditor's verb, and the check that makes the artifact falsifiable |

## 6. Where an LLM is genuinely required

Two places. Neither produces a verdict, and I would rather bound the blast radius than claim there is none.

**(a) Criterion segmentation, on the residue.** Numbered and bulleted criteria segment deterministically; free prose does not. A model proposes a segmentation under a strict schema with no loose-parse fallback, a human confirms once, and the result is **written back to Jira as numbered, id-bearing text**. After write-back the ids are literal strings and the model is never consulted again. *Blast radius:* a bad split produces a wrong criterion, visible in the Jira diff a human approved and correctable by editing Jira — which changes `textDigest` and invalidates affected rows, by design.

**(b) Binding suggestion** — proposing which existing test covers which criterion when no annotation exists. Output is a **proposed source edit**, a PR adding `@covers`, reviewed as code. *This is the worst failure in the system:* a wrongly accepted binding makes a criterion read `proved` by a test that does not test it. Bounds: every row records `bindingOrigin` as a distinct type plus `approvedBy`, so an auditor can filter the rollup to human-origin bindings; and E4 (§9) measures precision before it ships, with a pre-committed rule — below 60% precision@1 it ships off by default, below 40% it does not ship.

**What the artifact does not claim, stated plainly.** Specera proves that a *named test passed on a named commit*. It does not prove the test is a valid test of the criterion. `@covers FUT-803.AC2` on `assert True` produces a green gate. No mechanism in this design — or in any competitor's — closes that gap; the only defence is that the annotation is a reviewed source change with a named author in the record. Anyone evaluating this proposal should weigh that limit before weighing anything else in it.

## 7. Human approval gates

Mapped to [`sdlc-model.md`](sdlc-model.md) §1; each row names what the approver sees.

| Gate | Approver | Shown |
|---|---|---|
| Criterion ids (stage 2) | Product manager | Diff of the Jira description before/after id insertion, each proposed criterion highlighted. Re-approval when text changes |
| Binding (stage 7) | Engineer / reviewer | A normal code diff adding `@covers`, with the criterion text rendered beside the test body |
| Merge (stage 6) | PR reviewer | The check run: proved / unproved / unstable / waived counts, and every unproved criterion by id and text |
| Waiver | A **named second person**, never the PR author | Reason, expiry, linked ticket. Recorded as `verdict: waived` with the approver identity, counted separately in every rollup so waivers cannot hide inside a green number |
| Release (stage 9) | Release manager | Auto-assembled bundle: every criterion in the release, its verdict, its proving runs, every unexpired waiver and its approver |
| Policy change | CODEOWNERS on the policy path, second approver | The policy diff. Borrowed from GitLab's separate security-policy project pattern, including `warn` mode and an audit event on bypass |

## 8. Greenfield vs maintenance

**Build for a maintenance estate operating in forward-only mode.** The repo is old, large and has years of history; the product makes claims only about changes merged *after* adoption. Day one yields a correct small ledger rather than a large unverified one. `INFERENCE` This deliberately avoids the expensive half of maintenance mode — impact analysis and reconstructing decisions — which [`sdlc-model.md`](sdlc-model.md) §3 shows depends entirely on graph accuracy, which [`comparison.md`](comparison.md) §1 shows is commoditising and §3 shows is mistrusted.

**Backfill waits, behind a measured gate.** Reconstructing historical criterion↔test bindings is the §6(b) model path at a scale where no human can approve each one. Shipping it before E4 measures precision would fill the ledger with unverified claims — the exact failure the design exists to prevent. Backfilled rows, if ever shipped, carry `bindingOrigin: model-suggested` and never count toward a gate.

**Pure greenfield waits** because a new project has no test suite, no CI history, no tracker history, and no auditor asking questions — no urgency and no substrate.

## 9. The 90-day proof plan

Ordered so the cheapest kill comes first.

**E1 — substrate, weeks 1–2. Kills Claim A.** E1a: parse ≥200 work items across ≥3 real Jira projects with a deterministic parser only; measure % with ≥1 individually addressable criterion and % where parser and human segmentation agree exactly. E1b: over the last 500 merged PRs in each of the five repos in `withmartian/code-review-benchmark`'s corpus (Sentry, Grafana, Cal.com, Discourse, Keycloak), measure the share adding or modifying a test — via the PR API, not the merge-commit proxy whose unreliability I measured above. *Kill:* E1a <40%, or E1b <35% in a majority of repos.

**E2 — the deterministic spine, weeks 2–5.** End to end on two clones already on disk: `serena` (Python/pytest `--junitxml`) and `repomix` (TypeScript/vitest). Round trip: annotate → run → collect → canonicalise node ids → sign → post GitHub check → `specera verify` → replay, including a deliberately tampered statement that must fail verification. Criteria are synthesised from each repo's changelog, so **this tests the mechanism, not the substrate**. *Kill:* if the round trip does not work in both languages in three weeks, the "buildable in weeks" premise is false and the time-to-market advantage — the main thing this concept has instead of a moat — is gone.

**E3 — fill rate, weeks 4–6.** Run the pipeline over 30 real merged PRs from those two repos and measure the fraction of statement fields filled by a deterministic check versus empty versus model-asserted. This is [`product-concepts.md`](product-concepts.md)'s Concept 1 falsification test applied to Concept 3, deliberately. *Target:* ≥80% of criterion rows carry a deterministic execution record; **0%** of gate-affecting fields model-produced — the second should be structurally guaranteed, so measuring it verifies implementation matches design.

**E4 — bounding the LLM, weeks 5–8.** Hand-label a criterion↔test ground truth in `serena` and `repomix`; measure the suggester's precision@1 and @3. Run `withmartian/code-review-benchmark` (MIT) alongside as a **methodology control only** — it scores review comments, not bindings, so it calibrates the judge harness and does not score us. *Pre-committed rule:* precision@1 <60% → off by default; <40% → not shipped.

**E5 — Claim B, weeks 6–10.** Not a code experiment, and the most important one. Xray and Zephyr Scale pricing, Marketplace install counts, and published data models — specifically, do they store a commit SHA and a run id against a requirement? Plus 8–12 interviews in regulated shops. *Kill:* if auditors already accept manually asserted links and no buyer has been challenged on evidence quality, the pain is imaginary and nothing else matters.

**E6 — forgery, weeks 8–12.** An engineer is paid to produce a green gate for an unproved criterion. Named attacks: annotate a trivially-passing test; edit criterion text after proof; re-run only the passing shard; change policy in the same PR; forge the report artifact; replay an old signed statement onto a new SHA. *Success:* every attack is blocked **or visibly recorded** in the statement. Stated in advance: the first attack is not blockable (§6) and must appear as attribution, not as a defence.

**Day-90 go requires** E1a ≥40%, E1b ≥35%, E2 working in both languages, E3 ≥80% deterministic fill with 0% model-produced gate fields, and E5 finding a named budget line plus ≥3 buyers who say their current evidence would fail an audit. E4 gates only the suggester, not the product.

## 10. What I am not claiming

- **There is no technology moat.** The mechanism is convention plus integration and any incumbent could build it. The defences are time-to-market, cross-vendor neutrality (Jira + GitHub is served end-to-end by neither Atlassian nor GitLab), and a customer-owned ledger whose switching cost grows with retention. If the sponsor requires a technology moat, this concept is a no-go and Concept 2's constraint compiler is the only candidate that has one — with the weakest buyer.
- **Claim C is "they have not", not "they cannot".** Four commitments stand in Atlassian's way — a 90-day graph TTL, per-*author* Rovo Dev licensing, a Premium-gated Bitbucket merge check, an EAP graph API. `INFERENCE` Those are four decisions to reverse rather than one feature to ship: that buys time, not safety.
- **Claim B is unverified** and I have not softened that anywhere above.
- **The measured test-touching rates are from OSS infrastructure repos**, an optimistic reference class by an amount I cannot quantify.
- **Replay is only as good as the pinned runtime image**, and much existing CI pins none.
