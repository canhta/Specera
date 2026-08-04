# Blue team — private working notes

A2, 2026-08-04. **Not given to the red team**, by design: the red team must attack the
proposal, not a pre-defended version of it. Public artifact:
[`docs/spike/blue-team.md`](../docs/spike/blue-team.md).

Contents: anticipated attacks with prepared responses; what I deliberately left out of
the public doc and why; things I conceded on purpose; open questions for round 2.

---

## 0. Posture

The public doc concedes four things up front — no technology moat, Claim B unverified,
the `assert True` hole, and the optimistic OSS reference class. That is deliberate. A
red team that has to *discover* those spends its budget on them; a red team handed them
has to find something else, and what it finds is the information the round is for.

The two things I most want the red team to fail to break, because they are the actual
product: (a) that a customer-signed, replayable, retained record is worth money, and
(b) that the deterministic set in §5 really has no model in it.

---

## 1. Anticipated attacks and prepared responses

### A1. "Rovo already ships this. Detection is closed. You are dead."
**Strength: high if we ever slip into detection language. Low against the actual pitch.**

Response. Rovo grades the *diff*. `FACT` (atlassian-rovo.md §5) the AC checker never
runs or references a test, so a criterion reads "met" with no execution anywhere. Four
things it structurally does not produce: a per-criterion identifier; a machine-readable
record; a merge gate on GitHub; retention past 90 days. Plus `FACT` per-**author**
licensing — a PR from an unlicensed contributor is silently unchecked, which is exactly
the wrong shape for a compliance control.

Watch for: if the red team reframes us as "AC checking", concede the frame is fatal and
insist on the frame in blue-team.md §1 ("custody of evidence, not judgement"). Do not
argue that our detection is better. We have no detection.

### A2. "Engineers will not annotate their tests. This is a behaviour change and behaviour changes kill dev tools."
**Strength: highest of all attacks. I expect this to be the red team's main line.**

Honest position: this is the real risk and I have no data against it. Prepared response
has four parts, in order of honesty:

1. **Concede the general claim.** Annotation-based tools have a bad record.
2. **The annotation is one line and it is reviewed like code.** Compare `# noqa`,
   `//go:build`, `@pytest.mark`, `@Tag`, `codeowners` — all adopted, all one-line, all
   enforced by a gate. Adoption follows the *gate*, not the ergonomics.
3. **The gate creates the incentive.** Nobody annotates voluntarily. They annotate
   because the check is red. That means the gate must ship in `warn` mode first
   (GitLab's `enforcement_type: warn` pattern) and be promoted per-team.
4. **Fallback if it still fails:** derive the binding from a **naming convention**
   instead of an annotation — a test file path or test name containing the criterion id.
   Weaker (no `blobSha` anchor, easier to fake) but zero behaviour change beyond naming.
   This is a round-2 refinement, not a round-1 claim.

Do not say "it's only one line, it's fine". That loses.

### A3. "`@covers AC2` on `assert True` gives you a green gate. Your evidence proves nothing."
**Strength: high. Conceded in the public doc §6, deliberately.**

Prepared round-2 answer, deliberately withheld from blue-team.md because it is a defence
rather than part of the round-1 plan: **mutation testing on bound tests only**. Run
`mutmut`/`pitest`/`stryker` scoped to the code the bound test exercises and record a
`proofStrength` score in the ledger row. It is fully deterministic, it is exactly the
"does this test actually test anything" measurement, and scoping it to bound tests only
makes the cost tractable (whole-suite mutation testing is what makes the technique
impractical). No competitor does this.

Why it is not in round 1: it is a second deterministic subsystem, it needs a language
per implementation, and shipping it in phase 1 recreates the C1 scope failure. If the
red team lands A3 hard, this is the refinement to put in `evaluation.md`, with the cost
stated honestly.

Also true and worth saying: coverage gates, ArchUnit, and every requirements-traceability
tool ever sold have this same hole. We are not worse than the alternative; we are the
first to make the hole *attributable* (`bindingOrigin` + `approvedBy`).

### A4. "GitLab covers 8/10 rows. Your scope does not survive."
**Strength: medium. Mostly answered by narrowness.**

Response. Phase 1 is one artifact, two API integrations, one gate — it does not attempt
eight rows. And the overlap argument cuts our way where it matters: `FACT` GitLab's
requirements report is `{"1":"passed"}` with `{"*":"passed"}` a legal wildcard that marks
every open requirement satisfied in one line. That is not competition; it is the exhibit.

The real answer is buyer segmentation: our target is **Jira + GitHub**, which
`atlassian-rovo.md` §5 concludes is served end-to-end by neither vendor. A GitLab
Ultimate shop is explicitly not our customer, and we should say so rather than pretend
to compete there.

### A5. "No moat. Atlassian ships this in a quarter."
**Strength: high, and correct on the technology. Conceded publicly.**

Prepared response, not in the public doc: the question is mis-posed. Ask instead what
Atlassian must *give up*. Shipping this properly requires them to (a) raise or remove the
90-day graph TTL, (b) move Rovo Dev from per-author to per-repo licensing, (c) make the
gate work on GitHub, not just Bitbucket Premium, and (d) sign artifacts with an identity
the customer controls rather than Atlassian's own — which is a positioning inversion, not
a feature. Each is a decision someone owns and defends. That is 18 months of organisational
friction, not a quarter of engineering.

But state the limit: friction is not a moat, and the plan.md kill criterion is
"a competitor cannot ship it in one quarter", which on a strict reading this fails. If the
evaluation applies that criterion strictly and literally, **C3 dies and so does C1**;
only C2's constraint compiler survives, and C2 has no buyer. That trade should be surfaced
in `evaluation.md` explicitly rather than resolved quietly by either team.

### A6. "The ledger will be empty. Customers have no structured AC and no tests."
This is Claim A and E1 exists to kill it. Do not defend it — agree it is the top risk and
point at the threshold. If E1a comes back under 40% the honest move is to say so.

Do prepare one nuance: low AC parseability is not automatically fatal if the *same*
customers are the regulated ones who would author criteria for an auditor anyway. But that
is a hypothesis, and asserting it without evidence is exactly the cheerleading that loses
the round. Keep it as a round-2 question for E5 interviews.

### A7. "You become a Jira hygiene consultancy."
Related to A6 and genuinely dangerous. Response: the criterion write-back is a one-time,
human-approved, bulk operation, and it is the *customer's* PM doing it, not us. But
concede that if E1a is low, onboarding is a services engagement and the gross margin story
changes. That is a real commercial finding, not a rebuttal.

### A8. Prompt injection.
Vectors: (a) Jira description text reaching the segmentation model; (b) PR body / branch
name reaching the work-item resolver; (c) test names reaching the binding suggester.

Responses. (b) is pure regex — no model, no injection surface. (a) and (c) are model
paths, but both emit **schema-constrained proposals a human approves**, and neither can
write a verdict. The specific attack worth naming: crafted criterion text that makes the
segmentation *drop* a criterion, so it never appears in the gate. Mitigation is
deterministic and cheap — compare the model's criterion count against a deterministic
count of list items/sentences and fail closed on any reduction. Add this to the design
if the red team raises it; it is a real gap in the current spec.

Also: the model never gets tool access, never writes to Jira directly (the human's
approval action does), and never touches the ledger.

### A9. Excessive permissions.
What we actually need: GitHub App with `checks: write`, `contents: read`,
`pull_requests: read`, and Actions artifact read. Jira: `read:jira-work`,
`write:jira-work` (for criterion id write-back), plus builds/devinfo write scopes.

The two that a security review will stop on: `write:jira-work` (we edit descriptions) and
anything that writes to the repo. Prepared answers: criterion write-back can be done
**by the PM in their own session** via a link, not by our service account — we generate
the proposed text, the human applies it. And git notes are written **by the customer's CI
job under the repo's own token**, so we never need `contents: write`. Both are real design
changes worth making; note them as such rather than claiming they are already true.

Contrast to have ready: `FACT` Copilot's cloud agent requires adding Copilot as a
**bypass actor** on branch protection. We require the opposite — we add a required check.

### A10. Flaky tests make the gate unusable.
Fair. `flake-guard` marks unstable proof as not-proof, which in a flaky suite turns the
gate permanently amber. Honest answer: that is information, not a bug — but it is also an
adoption killer if it lands on day one. Mitigation: `flakeWindow` is recorded from day one
but only *enforced* after a per-repo opt-in, and the rollup shows "criteria proved only by
unstable tests" as a separate number so it can be driven down deliberately.

### A11. Database migrations and rollback.
From plan.md's mandatory list, and not addressed in the public doc. Prepared answer: the
ledger is keyed by commit SHA, so a rollback to an earlier SHA simply makes that SHA's
statement the current one — no reconciliation needed, and this is a genuine benefit of
SHA-keying that the competitors' verdict-only artifacts cannot match. What we do **not**
handle: a criterion proved at SHA X where the proof depended on a migration that has since
been rolled back. Nothing in the design detects that. Concede it; it needs runtime
evidence, which is C1 territory.

### A12. "You are Xray with signatures."
The sharpest *commercial* attack. Response: partly yes — and that is the point, because
Xray's link is manually asserted. The delta is execution proof, commit binding, customer-
controlled signing, and retention. Whether that delta is worth a purchase order is exactly
Claim B, which is `UNVERIFIED`. Do not overclaim here; E5 decides it.

### A13. Graph accuracy and freshness (mandatory challenge item).
Not applicable — phase 1 has no graph. Make sure this lands as *deliberately out of scope*
rather than unanswered, and note that avoiding the graph is the single biggest reason C3
beat C1 in this analysis. `comparison.md` §1 (category six months old, unconsolidated,
commoditising) and §3 (mistrusted) are the supporting facts.

### A14. Cost and performance.
Also mostly a strength: the hot path is XML parsing plus a few API calls, with no model
inference at all. Contrast: `FACT` GitLab charges ~4 credits (~$4) per agentic security
run; `FACT` Rovo Deep Research is 100 credits against a 25-credit/user/month Standard
allowance. Our per-PR marginal cost is close to zero. The real cost is storage (retained
JUnit reports) and it is small and text-compressible.

### A15. Admin bypass defeats the gate.
True of every required status check on every platform. Answer: bypass emits an audit event
and appears in the release rollup as a distinct count. This is GitLab's own pattern
(`bypass_settings` + audit events on bypass) and it is the honest ceiling — no software
control survives an administrator.

---

## 2. What I deliberately left out of the public doc

| Withheld | Why |
|---|---|
| Mutation testing as `proofStrength` (A3) | It is a defence against the sharpest anticipated attack. Holding it lets the red team land A3 honestly; it becomes the round-2 refinement |
| The "naming convention instead of annotation" fallback (A2) | Same reason. It is a weaker mechanism and presenting it early would blur the round-1 proposal |
| The Atlassian-must-give-up-four-things argument (A5) | It is a rebuttal, not a plan. The public doc states the weakness and lets the red team price it |
| Buyer-segmentation counter to the GitLab scope attack (A4) | Partially present (§10 mentions cross-vendor neutrality) but not developed as a defence |

Nothing withheld is a *fact*. Every fact I have is in the public doc, including the four
that hurt.

---

## 3. Things I changed my mind on while writing

- **Jira devinfo is the wrong write path for test evidence.** Prior spike documents
  (`comparison.md` §5, `sdlc-model.md` §2, `product-concepts.md` C1) all name
  `POST /rest/devinfo/0.10/bulk` as the evidence path. Verified: devinfo has
  repositories/commits/branches/pullRequests and **no test or evidence entity type**. The
  **Builds API** `POST /rest/builds/0.1/bulk` has a typed `testInfo {totalNumber,
  numberPassed, numberFailed, numberSkipped}` plus `references[]` (commit + ref). Devinfo
  still carries the PR↔work-item edge and an evidence permalink via per-entity `url`.
  **The coordinator should correct the other documents.**
- **Per-testcase `<properties>` cannot be the binding carrier.** pytest, gotestsum and
  mocha-junit-reporter support it; jest-junit does not (issue #135); JUnit5 uses
  `<system-out>`. So the binding must live in **source** and join to the report on the
  **test node id**. That is strictly better anyway — a source annotation has a `blobSha`
  and a git author; a report property has neither. But it makes the node-id canonicaliser
  load-bearing, and Jest/vitest node ids are runtime-computed from `describe`/`it` string
  literals. This is the top unpriced engineering risk and it is in the public doc.
- **Digest-only retention is insufficient.** GitHub Actions artifacts expire at 90 days by
  default, so verification step 5 would fail on the same timescale that defeated Rovo.
  Retain the report text, not just its hash. Fixed in the public doc.
- **Rekor is public.** Fulcio certs carry the repo URL and workflow path. Public Rekor
  must not be the default for private repos. Flagged to `security.md`.

---

## 4. Open questions for round 2

1. **Claim B** — Xray / Zephyr Scale pricing, install counts, and whether either stores a
   commit SHA and run id against a requirement. Highest-value unknown in the whole spike.
2. Do auditors in fintech/medtech/gov actually reject manually asserted traceability
   today, or has nobody been challenged? E5. If nobody has been challenged, the concept
   fails commercially regardless of engineering.
3. Enterprise AC parseability rate. All current evidence is n=3 plus OSS proxies.
4. Whether `plan.md`'s kill criterion ("a competitor cannot ship it in one quarter") is
   meant strictly. Applied strictly it kills C1 and C3 and leaves only C2, whose buyer has
   no budget — i.e. it kills the spike. The coordinator should rule on this explicitly;
   neither blue nor red should resolve it by assumption.
5. Node-id canonicalisation for Jest/vitest — the E2 TypeScript half decides it.
6. Whether the segmentation criterion-count check (A8) closes the injection gap, or whether
   free-prose AC should simply be rejected as unsupported in v1.
