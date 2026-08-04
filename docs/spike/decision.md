# Decision — no-go on the proposed platform

**Verdict: NO-GO** for Specera as scoped, after two rounds.
Date 2026-08-04. Coordinator, on the evidence below.

`plan.md` permitted three rounds. Round 3 was not run because round 2 produced a
determinate answer; a further round would have been spent looking for a reason to
proceed, which is not what the loop is for.

## 1. The decision

Do not build the eleven-stage SDLC platform. Do not build any of the three
concepts at the scope proposed.

`INFERENCE` The strongest surviving idea — a customer-run merge gate over
requirement↔test evidence — is a feature, not a company. It should be recorded
and revisited only if one of the reopening conditions in §5 becomes true.

## 2. What decided it

Three findings, in descending order of weight. Each was **measured or verified**,
not argued.

### 2.1 The last differentiator is already a shipping product

`FACT` Tricentis **Vera**, integrated with qTest and Jira, ships 21 CFR Part 11
electronic signatures, a centralised review-and-approval portal, record locking,
auditable electronic records, and pre- and post-execution approvals for automated
tests (https://www.tricentis.com/products/digital-validation-vera;
https://docs.tricentis.com/qtest-saas/content/integrations/vera/using_qtest_test_cases_in_vera.htm
— both HTTP 200, coordinator-verified 2026-08-04).

`INFERENCE` This is decisive because it is precisely the claim
[`evaluation.md`](evaluation.md) §5 identified as the one carrying the price —
tamper-evident attribution — sold to precisely the regulated buyer that same
section identified as the only plausible one, inside Jira, today. The round-2
thresholds did not anticipate it, which is a limitation of the thresholds rather
than a reason to discount the finding.

### 2.2 The residue after Xray is two items, and both are weak

`FACT` Xray already ships four of the five steps of the surviving concept:
`@Requirement("KEY-123")` as a free EPL-2.0 JUnit annotation
(`Xray-App/xray-junit-extensions`, pushed 2026-04-15), JUnit XML import from CI, a
`Revision` field, and requirement coverage computed from executed runs.

Round 2 tested whether Xray's versions were weak enough to leave room. The
literal reject-triggers did **not** fire — `FACT` `Revision` is an unvalidated
free-text Jira custom field, coverage analysis scopes are Latest / Version / Test
Plan with no by-commit scope, and no merge gate exists in Xray, Zephyr Scale, or
qTest (`gh api orgs/Xray-App/repos` → 42 repos, zero Checks/App/Action
integration). So a gap is real.

But two of the four claimed differentiators were eliminated in the same test:
`FACT` retention is customer-determined with no vendor TTL and history is fully
mutable (statuses manually overridable, bulk delete on test runs), so "we retain
longer" is not a differentiator; and §2.1 eliminates tamper-evidence.

`INFERENCE` What remains is a customer-run merge-gate CLI over a competitor's
API. That is a thin, copyable product whose main asset is an integration with the
incumbent it competes against.

### 2.3 The evidence key does not survive merge

`FACT` Round 2 settled round 1's contested number properly, by ancestry test over
**1,160 merged PRs across 18 repositories** (0 unknown SHAs, 0 rate-limit
failures): pooled head-SHA survival **19.83%**, mean-of-repos 23.83%, **median
repo 2.0%**, 8 of 18 repos at exactly 0%, and **15 of 18 losing the majority** of
head SHAs to squash or rebase. Method validated against merge-parent counts
(repomix: 2 parents, survives; potpie: 1 parent, orphaned).

This refutes the coordinator's own weaker 6/19 proxy and substantially confirms
the red team's 13/19. `INFERENCE` The design's chosen key — `(work item key,
commit SHA)` — is orphaned for four out of five merged pull requests in this
corpus. A tree-digest fallback exists but was never designed, costed, or tested.

### 2.4 Supporting findings

- `FACT` The substrate is thinner than the proposal required. Median test-touch
  32–34% across 19 repositories with **9–10 of 19 below the blue team's own
  stated ≥35% threshold** ([`.spike/verification-coordinator.md`](../../.spike/verification-coordinator.md)).
  The blue team failed a threshold it set itself, by sampling the three
  highest-scoring repos in the corpus.
- `FACT` The core claim is unprovable. No design here or in any competitor can
  show that a passing test exercises the criterion it claims;
  `def test_ac2(): assert True` plus an annotation yields a valid signed green
  gate ([`security.md`](security.md)).
- `FACT` 0 of 19 repositories contain an ADR **or** configure a free architecture
  linter — measured absence of demand, which killed Concept 2 more decisively
  than its own falsification test would have.
- `FACT` Every incumbent AI reviewer is constitutionally advisory, and the
  category ships findings at ~33% precision independently measured
  ([`comparison.md`](comparison.md) §3).

## 3. What is explicitly *not* the reason

`INFERENCE` Stated because these are the plausible-sounding wrong reasons:

- **Not** "the incumbents are too big." A real gap exists — no test-management
  vendor ships a merge gate, and Rovo's detection-not-evidence asymmetry is
  genuine and explainable by Atlassian's own constraints.
- **Not** "the technology is infeasible." Most of it is straightforwardly
  buildable; [`roadmap.md`](roadmap.md) phase 1 is a real plan.
- **Not** red-team pessimism. The red team's headline number (13/19) was carried
  as `UNVERIFIED` until round 2 tested it, and the coordinator's competing number
  was the one refuted.

The reason is narrower and harder: **the parts that are defensible are already
sold by someone, and the part that is unsold cannot be claimed truthfully.**

## 4. What survives and should be kept

`INFERENCE` The research has durable value independent of the verdict:

- The **competitor corpus** ([`competitors/`](competitors/index.md)) — 29 files,
  source-level, with licence verdicts. Reusable for any adjacent decision.
- **Licence findings** that constrain any future build: GitNexus is PolyForm
  Noncommercial, stakgraph has no licence, sourcebot is FSL, bloop's pre-2024-04
  history contains a proprietary tree ([`inventory.md`](inventory.md)).
- **Two unowned mechanisms**, cheap and still unoccupied: per-edge confidence that
  is actually *filtered at query time* (no engine does this), and artifacts keyed
  by the commit they describe (no tool does this).
- The **supply-chain finding** ([`.spike/findings-supply-chain.md`](../../.spike/findings-supply-chain.md)) —
  first-hand evidence that cloning repositories surfaced agent-directive files
  into this spike's own coordinator. Relevant to any product ingesting customer
  repositories.
- `withmartian/code-review-benchmark` (MIT) as an independent evaluation harness.

## 5. What would reopen this

`UNVERIFIED` Two questions were left open by round 2 and are cheap to answer. If
either resolves favourably, revisit — otherwise this decision stands:

1. **Is Vera's audit trail third-party cryptographically verifiable, or only
   append-only inside Tricentis?** If the latter, an independently verifiable
   attestation is still unoccupied for buyers who distrust a single vendor's log.
   Cost: reading documentation.
2. **Does enterprise head-SHA survival materially exceed 19.83%?** The corpus is
   OSS and may be unrepresentative. Cost: the same ancestry test in 2–3 real
   estates.

A third, structural condition: `INFERENCE` the one asymmetry no single vendor can
close by shipping a feature is **cross-tracker, cross-repository evidence** —
Atlassian sees Jira, GitHub sees code, neither sees both. If a buyer is found who
pays for that specifically, the analysis changes. Nothing in this spike found one.

## 6. Method note

`FACT` The loop worked as designed and its most valuable outputs were the
self-corrections: the blue team's designated critical fact was falsified; the
coordinator's own kill criterion was defective and was amended on the record
([`plan.md`](plan.md)); the coordinator's SHA measurement was refuted by a better
test; and a coordinator hypothesis about artifact grounding was refuted by an
agent that checked instead of agreeing.

`INFERENCE` A spike that produces a no-go in two rounds, for reasons that can be
checked by a reader who disagrees, is a cheaper outcome than a build that
discovers §2.1 in month nine.
