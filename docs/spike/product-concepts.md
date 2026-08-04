# Product concepts — three candidates

Three concepts that differ in **wedge, buyer, and failure mode**. They are
alternatives, not layers of one product. Constraints are inherited from
[`comparison.md`](comparison.md) §6 and the stage model in
[`sdlc-model.md`](sdlc-model.md); competitor detail is linked, not restated.

Standing rules applied to all three, from [`plan.md`](plan.md)'s evidence order:

1. Deterministic verification beats model judgement wherever a deterministic check
   exists. `FACT` basis: the category ships findings at roughly one-in-three
   precision ([`comparison.md`](comparison.md) §3).
2. Every artifact is keyed by `(work item key, commit SHA)`.
3. Every verdict is a status object with a stable identifier, not prose.
4. Any concept whose core loop is "an LLM decides" says so in its own section.

---

## Concept 1 — Continuous Change Assurance

The mandated candidate, evaluated on its merits and permitted to lose.

**Wedge** — A single signed record per change that states what the change was
predicted to affect, which deterministic checks were run, what each check
returned, which acceptance criteria they establish, and — after deploy — whether
the predicted impact matched the observed impact. Nothing in the competitor set
produces a retained, machine-readable record of a change at all; every incumbent
emits advisory prose that closes no stage
([`comparison.md`](comparison.md) §2 Gap 4).

**Buyer** — VP Engineering or Head of Platform at a company with 5+ services and a
Jira + GitHub estate. Currently paying for: [Greptile](competitors/services/greptile.md)
or [CodeRabbit](competitors/services/coderabbit.md) at $20–30/dev/month for review
comments, plus [Rovo Dev](competitors/services/atlassian-rovo.md) at $20/dev/month,
plus manual release-readiness spreadsheets. `INFERENCE` The budget exists but is
already committed to detection tools; this concept must displace one, not add to
the stack.

**Mechanism** — Concretely:
- **Temporal SDLC evidence graph.** Entity/edge/record catalogs modelled on
  [potpie](competitors/potpie.md)'s ontology (Apache-2.0, reusable): typed
  `allowed_pairs`, `singleton` edges with automatic `invalid_at` supersession,
  per-entity `freshness_ttl_hours`, and a per-claim `evidence_strength ∈
  {deterministic, attested, inferred, hypothesized}`. Deterministic extractors own
  topology; models may only write `inferred`/`hypothesized` claims.
- **Code layer.** zoekt (Apache-2.0) for lexical, serena's `solidlsp` (MIT) for
  compiler-grade symbols. Confidence is stored **and filtered**: default traversal
  to the high-confidence subset, low-confidence edges split into a separately
  named relationship type as [codegraphcontext](competitors/codegraphcontext.md)
  does, so opting into them requires typing the scary name
  ([`comparison.md`](comparison.md) §2 Gap 1).
- **Change Passport** assembled per PR: work-item keys resolved from branch,
  commits and PR body; the impact set; the check matrix; the AC verdict table.
- **Gates.** GitHub Checks API conclusion (the required-check slot Copilot review
  deliberately leaves empty) and GitLab external status checks. Written into Jira
  via `POST /rest/devinfo/0.10/bulk` so it renders in the native dev panel.
- **Blue-team plan / red-team challenge.** LLM-generated, explicitly labelled
  `hypothesized`, never gate-blocking.
- **Production feedback.** Compare the predicted impact set against services that
  actually errored or changed latency after the deploy.

**Evidence it produces** — A Change Passport keyed to `(PR number, head SHA,
work-item keys)`, containing only claims that name their producing check
(`checkId`, `command`, `exitCode`, `artifactDigest`), signed as an in-toto
attestation over the same predicate machinery GitLab already emits for build
provenance. Verifiable by re-running the named checks against the named SHA.

**Minimum viable core** — One repo, one PR, one language. Resolve work-item keys →
run the repo's existing test and scan commands → record each result with its
digest → emit a signed passport → post one GitHub check → write one dev-info
entry. **Excluded from the MVC:** cross-repository impact, red-team challenges,
blue-team planning, production feedback, the temporal graph itself. `INFERENCE`
If the passport is not valuable with an empty impact set, the graph will not save
it — and the graph is the expensive half.

**Why it might fail** — Scope. This is nine features in a trench coat, and the
strongest argument against it is [`comparison.md`](comparison.md) §4: for a GitLab
Ultimate customer roughly 70% of it already ships. Cross-repository impact
analysis depends on a resolved multi-language graph, which is the hardest thing in
the spike and is being attempted by four teams simultaneously. Predicted-vs-actual
impact requires observability integration nobody has scoped. And a passport whose
fields are mostly empty — because the repo has no tests, or the PR has no ticket —
is a compliance ornament.

**What would falsify it** — Build the passport generator against 20 real merged
PRs in two large OSS repos. Measure: what fraction resolve to a work item; what
fraction of passport fields are filled by a deterministic check versus left empty
or model-asserted. `INFERENCE` If more than half the fields are empty or
model-asserted, the artifact is decoration and the concept fails on its own terms.

---

## Concept 2 — Executable Architecture (ADR-as-code)

**Wedge** — An architecture decision that is a **machine-checkable constraint over
parsed code**, enforced as a merge gate and versioned in the repo beside the code
it governs. `FACT` Architecture/ADR is the only SDLC stage with zero coverage
across all 29 products examined ([`comparison.md`](comparison.md) §4,
[`sdlc-model.md`](sdlc-model.md) §2). Today an ADR is a Confluence page that
nothing reads and nothing checks.

**Buyer** — Chief architect or platform lead at a company enforcing a service or
module boundary. Currently paying for: nothing, or Backstage/Structurizr for
diagrams, or an ecosystem linter (ArchUnit, dependency-cruiser, import-linter) that
one team configured and nobody maintains. `INFERENCE` This is the weakest budget of
the three, and that is the concept's central commercial risk.

**Mechanism** — An ADR is a markdown file in `docs/adr/` with front-matter and a
`constraints:` block. Each constraint compiles to a query over a resolved symbol
and import graph (serena `solidlsp`, MIT). Three constraint kinds in the first
cut: forbidden dependency (`domain/** must not import infra/**`), layer ordering,
and required-boundary-crossing (`any call from api/** to db/** must pass through
repository/**`). Evaluation is a **graph query, not a model call** — pass/fail
with file:line for every violation. The LLM's only jobs are drafting ADR prose and
*proposing* a constraint block for a human to approve; the proposal is generated
under a schema with no loose-parse fallback, as
[gitdiagram](competitors/gitdiagram.md) does. Result posts as a GitHub check.
Backfill mode for maintenance repos: mine the existing import graph for boundaries
already 95%+ respected and propose them as candidate constraints.

**Evidence it produces** — An ADR conformance attestation keyed to
`(adr-id, constraint-id, commit SHA)` with the exact query, the violation list, and
file:line for each. Verifiable by re-running the query — no model in the loop.
Because the ADR is a repo file, its history and supersession are `git log`, not a
bespoke store.

**Minimum viable core** — One language (TypeScript or Python), the three
constraint kinds above, a CLI that exits non-zero, and a GitHub Check. No graph
database, no Jira integration, no LLM required to run it.

**Why it might fail** — In several ecosystems these rules are already enforceable
for free: ArchUnit (Java), dependency-cruiser (JS/TS), import-linter (Python).
`INFERENCE` If most useful constraints reduce to path-pattern dependency rules
that a free linter already checks, the product is a cross-language wrapper with a
nicer report — a feature, not a company. Constraints richer than dependency rules
(behavioural, runtime, cross-service) need exactly the resolution quality that is
hardest to achieve. And architecture governance buyers are architects, who are
influential and under-budgeted.

**What would falsify it** — Take five OSS repos with published architecture
documentation. Write constraints from their own docs. Measure two things: (a) how
many real violations exist and what fraction are true positives on manual review;
(b) **what fraction of the constraints an existing free linter in that ecosystem
could already express.** `INFERENCE` (b) is the killer test — if it exceeds ~70%,
the concept is dead regardless of how well (a) goes.

---

## Concept 3 — Executable Acceptance Evidence

**Wedge** — An acceptance criterion is marked satisfied only when a **named,
executed test** proves it, and the binding survives indefinitely. `FACT` Rovo's
AC checker grades the *diff*, not a test run, so a criterion can read "met" with
no test proving it ([atlassian-rovo.md](competitors/services/atlassian-rovo.md)
§5). `FACT` GitLab records `Requirement IID → "passed"` with no reference to which
test or commit proved it ([gitlab-duo.md](competitors/services/gitlab-duo.md) §1).
`FACT` Rovo's own graph truncates status history at **90 days** (first-hand,
2026-08-04). Nobody produces the binding, and the incumbents cannot retain it.

**Buyer** — QA lead or engineering manager in a regulated or audited environment
(fintech, medtech, gov contracting) who must answer "prove this requirement was
tested before release" to an auditor. `UNVERIFIED` They are currently paying for a
Jira test-management add-on (Xray, Zephyr Scale) that stores **manually asserted**
requirement↔test links with no execution proof. Would be verified by pricing pages
and Atlassian Marketplace install counts for those apps — this is the single most
important commercial fact to check in round 2, because it is the only concept of
the three with a plausible pre-existing budget line.

**Mechanism** — Deterministic end to end:
1. **AC identity.** A parser assigns stable ids (`FUT-803.AC2`) to the numbered
   acceptance criteria already present in Jira descriptions — `FACT` observed
   first-hand as `## Acceptance Criteria` / AC1–AC6 blocks
   ([atlassian-rovo.md](competitors/services/atlassian-rovo.md) §5). Ids are
   written back to Jira so they are stable and human-visible.
2. **Binding.** A test declares the criteria it covers via an annotation or tag
   (`@covers FUT-803.AC2`, a Gherkin tag, a pytest marker). The binding is a
   durable source annotation, not a database row.
3. **Execution.** CI emits JUnit XML / TAP; the collector maps test node ids to
   AC ids and records `(AC id, test node id, outcome, commit SHA, run URL,
   duration)`.
4. **Publication.** A GitHub check fails if any AC on the linked work item has no
   passing bound test. The result is written to Jira via the Development
   Information API so it renders in the native dev panel.
5. **Retention.** The AC↔test↔run ledger is append-only and outlives both Rovo's
   90-day window and the CI provider's artifact expiry.

**LLM role, stated plainly** — Exactly one: *suggesting* which existing test
covers which AC when no annotation exists. The suggestion is a proposed source
edit that a human accepts, after which the binding is a literal annotation and the
model is never consulted again. No verdict is ever model-produced. `INFERENCE`
This is the lowest LLM dependence of the three concepts.

**Evidence it produces** — A coverage ledger row per
`(AC id, test node id, commit SHA, run id, outcome)`, and a per-release rollup:
"every AC in release 4.2 was proved by these test runs on these commits."
Verifiable by re-running the named tests at the named SHA.

**Minimum viable core** — One CI format (JUnit XML), one annotation convention,
one tracker (Jira), one gate (GitHub check). No graph, no code parsing beyond
reading annotations, no model. `INFERENCE` This is buildable in weeks, and its
first evidence is produced on the first CI run after adoption.

**Why it might fail** — It has no moat in the mechanism; the work is integration
and convention, and any incumbent could ship it in a quarter. It also depends
entirely on customer discipline: teams that neither write structured acceptance
criteria nor write tests get an empty ledger and blame the tool. And requiring
engineers to annotate tests is a behaviour change, which is the most reliable
adoption killer in developer tooling.

**What would falsify it** — Sample 200 work items across real Jira projects and
the corresponding merged PRs. Measure: (a) what fraction of work items have
machine-parseable, individually addressable acceptance criteria; (b) what fraction
of merged PRs add or modify at least one test. `INFERENCE` If (a) is below ~40%,
there is no substrate and the product spends its life doing requirement cleanup
instead of evidence. Second test: attempt AC↔test binding suggestion on a repo
with an existing hand-labelled mapping and measure precision — if it is near the
category's ~33%, step 1 of adoption is unusably noisy.

---

## Comparison

`INFERENCE` throughout; ratings are relative to each other, not absolute.

| | C1 Continuous Change Assurance | C2 Executable Architecture | C3 Executable Acceptance Evidence |
|---|---|---|---|
| **Differentiation strength** | High as an artifact, low as a mechanism — every component exists somewhere; the assembly does not | **Highest** — occupies the one stage with zero competitor coverage | Medium — the mechanism is obvious once stated and copyable in a quarter |
| **Scope risk** | **Severe.** Nine sub-features, a multi-language graph, and an observability integration | Moderate — bounded by language coverage, but resolution quality is the whole product | **Lowest.** Two parsers and two API integrations |
| **LLM dependence** | Medium — assembly is deterministic, but impact prediction and challenges are not | Low — enforcement is a graph query; the model only drafts constraints for human approval | **Lowest** — one advisory suggestion, never a verdict |
| **Time to first evidence** | Longest — weeks to a passport, months to a credible impact set | Medium — needs a resolver plus a constraint compiler | **Shortest** — first CI run after adoption |
| **Depends on graph accuracy** | Totally | Substantially | Not at all |
| **Pre-existing buyer budget** | Yes, but committed to detection tools | Weakest of the three | Plausible and specific, but `UNVERIFIED` |
| **Lifecycle fit** ([`sdlc-model.md`](sdlc-model.md) §3) | Maintenance | Greenfield, with a backfill path | Both |

`INFERENCE` **Strongest, offered as input to [`evaluation.md`](evaluation.md), not
as a decision.** Concept 3 is the strongest bet, on three grounds. First, it is
the only one whose core loop contains no model verdict, which directly satisfies
[`plan.md`](plan.md)'s evidence ordering and sidesteps the ~33%-precision problem
that [`comparison.md`](comparison.md) §3 identifies as the category's defining
weakness. Second, it produces evidence on day one with no graph, so it can be
falsified cheaply and cannot fail the way Concept 1 fails — silently, after
months, with an empty artifact. Third, it targets the exact seam the research
proved open: Rovo has closed the *detection* half of Gap 4 and structurally cannot
close the *evidence* half, because its verdicts are prose, its graph forgets after
90 days, and its graph API may not be shipped on. The honest counterweight is that
Concept 3's mechanism is not defensible — it is convention and integration, and
Atlassian could ship it — so it wins on time-to-market and loses on moat.

`INFERENCE` **Weakest.** Concept 2, on commercial rather than technical grounds.
Its wedge is the most genuinely uncontested finding in the whole spike, and it is
the concept most likely to produce a technically excellent product nobody buys:
the buyer is an architect with no budget, and the falsification test in its own
section — how much of it a free ecosystem linter already does — is the one most
likely to come back badly. `INFERENCE` Its best use may be as a differentiating
*module* of whichever concept wins, rather than as a company.

`INFERENCE` Concept 1 is not weakest, but it carries the highest variance: if the
graph works and the passport fills, it is the largest product; if either fails, it
consumes the entire runway before anyone finds out. Its minimum viable core above
is stated deliberately narrowly so that the red team attacks the actual proposal
rather than the maximal version.
