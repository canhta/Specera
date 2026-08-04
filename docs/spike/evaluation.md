# Evaluation — round 1 score and ruling

Agent A5, 2026-08-04. Referee. Input: [`plan.md`](plan.md) (amended kill criterion and
coordinator ruling, both binding), [`product-concepts.md`](product-concepts.md),
[`sdlc-model.md`](sdlc-model.md), [`comparison.md`](comparison.md), [`blue-team.md`](blue-team.md),
[`red-team.md`](red-team.md), [`security.md`](security.md), `.spike/verification-coordinator.md`,
and my own re-measurement of the 19 clones. Labels per [`plan.md`](plan.md).
I did not read `.spike/blue-private.md`.

**Verdict: PIVOT** (§6). Scores §3. The finding that decided it: §4.

## 1. Scoring model, stated before the scores

Eight criteria summing to 100. Scores 0–10 and **descriptive**: the amended kill
criterion is a **gate applied separately** in §4, not a term in this sum. A concept can
score well and still be killed.

| Criterion | Wt | Why this weight |
|---|---|---|
| Compounding advantage | 22 | [`plan.md`](plan.md) makes it the kill criterion; must dominate, must not decide alone |
| Customer value / budget | 18 | Whether anyone will move budget — the only thing no engineering rescues |
| Adoption feasibility | 16 | The most measurable failure mode in this spike, and shared by all three |
| Evidence strength | 12 | How much of the case is measurement vs anecdote — [`plan.md`](plan.md)'s ordering made operational |
| Scope realism | 12 | Round 1's largest claimed-vs-actual gap; sets runway consumption directly |
| Security defensibility | 10 | For an audit-evidence product the security posture *is* the product |
| Cost to first revenue | 5 | Real but derivative of scope; low to avoid double-counting |
| Licensing / legal | 5 | [`comparison.md`](comparison.md) §5 resolved it for all three; low variance |

Precision caveat, stated once: **customer value rests on one anecdote for every concept**
(`FACT` n=3 live Jira work items, [`blue-team.md`](blue-team.md) §2) plus inference from
competitor pricing. No concept's demand was measured. Read that row as ranks, not values.

## 2. What I re-measured, and which numbers I use

Run against `.spike/clones`, 2026-08-04.

| Claim | Red | Coordinator | **Me** | Ruling |
|---|---|---|---|---|
| Test-touch median (19 repos) | 34% | 32% | **41%** | Do not publish a median |
| Repos below 35% | 10/19 | 10/19 | **9/19** | **Use this** |
| ADR / decision-record dirs | 0/19 | — | **0/19** | `FACT` confirmed |
| Arch-linter config or rule | 0/19 | — | **0/19** | `FACT` confirmed |
| Requirement↔test annotations | 0/19 | — | **0/19** | `FACT` confirmed |
| Repos emitting JUnit XML in CI | 2/19 | — | **2/19** (GitNexus, repomix) | `FACT` confirmed |
| Down-migrations in corpus | 0/105 | — | **0 found** | `FACT` confirmed |

`FACT` **The test-touch median is not a stable number.** Four measurements give
45 / 34 / 32 / 41. My run replicates the red team per-repo within ~2 points on 16 of 19;
the median moves 34→41 because `potpie` sits exactly on it and shifts with a one-token
change to the test-path regex. `INFERENCE` What carries is the invariant across all three
full-corpus runs: **9 or 10 of 19 repos fall below the blue team's own pre-committed ≥35%
threshold** — bad for C3 on its own terms. The blue team's 45% is rejected (sampling, per
the coordinator; my full-corpus run does not reproduce it either). Per the coordinator's
instruction I score the concept, not the advocacy: that threshold was pre-committed
publicly, which is the only reason it was checkable.

`UNVERIFIED` **SHA rewriting at merge.** Red team 13/19 by ancestry test; coordinator
6/19 by a proxy it disowns. I reproduced neither. The ancestry test is the better method
per [`plan.md`](plan.md)'s ordering, but one unreplicated run is not a `FACT`. Carried as
`UNVERIFIED` with a mandatory round-2 reproduction (R2-1). The direction is not in
dispute: squash-merge destroys the key [`blue-team.md`](blue-team.md) §4 puts in
`subject[0].digest.gitCommit`, and the design has no answer.

`FACT` **Xray occupies the wedge**, coordinator-verified: `Xray-App/xray-junit-extensions`,
EPL-2.0, pushed 2026-04-15, not archived; README documents `@Requirement("CALC-1234")`,
`@Requirements`, `@XrayTest`; Marketplace lists "Xray – Test Management for Jira"
(Xblend). I use these specifics, **not** the 25,849 install figure, which nobody verified.

`INFERENCE` A correction neither team made: **the OSS corpus is biased in opposite
directions on the two adoption numbers.** Optimistic for test discipline (blue team
concedes). Almost certainly *pessimistic* for CI report formality — 17/19 emit no JUnit
XML largely because the corpus is Go/Rust/bare-pytest, where an enterprise Maven/surefire
or RSpec estate emits per-test XML by default. Red team §9's "step 0 is a CI change for
~90% of repos" is its weakest measured claim. R2-2 tests it.

## 3. Scores

| Criterion (wt) | C1 Change Assurance | C2 Executable Architecture | C3 Acceptance Evidence |
|---|---|---|---|
| Compounding advantage (22) | 4 | 2 | 4 |
| Customer value / budget (18) | 4 | 2 | 4 |
| Adoption feasibility (16) | 2 | 2 | 2 |
| Evidence strength (12) | 2 | 4 | 3 |
| Scope realism (12) | 1 | 6 | 3 |
| Security defensibility (10) | 1 | 9 | 5 |
| Cost to first revenue (5) | 1 | 7 | 5 |
| Licensing / legal (5) | 8 | 9 | 9 |
| **Weighted /10** | **2.8** | **4.1** | **3.8** |

Evidence behind the non-obvious cells:

- **C1 scope 1 / security 1.** [`security.md`](security.md) finding 4: "run the repo's
  existing test and scan commands" is RCE from an untrusted repo *inside the MVC*, and §1
  shows it is not hypothetical — cloning 19 repos surfaced three `repomix/.claude/skills/`
  entries as invocable capabilities with no file read. Plus org-wide `contents:read` (§3)
  and total dependence on a graph layer [`comparison.md`](comparison.md) §1 shows is six
  months old and commoditising.
- **C2 security 9.** [`security.md`](security.md) §8: the only concept where both §0
  asymmetries fall the right way — rule lives in `docs/adr/**`, evaluated from the base
  branch, verification needs no Specera signature, runs as a CLI holding nothing.
- **C2 value 2 / adoption 2.** `FACT` (my run) 0/19 repos contain any ADR, and 0/19
  configure any architecture linter though dependency-cruiser, import-linter and
  `no-restricted-imports` are free. The second is the damning one: measured absence of
  *demand*, not of supply.
- **C2 evidence 4, not lower; scope 6, not 7.** The uncontested-stage claim is well
  evidenced (0/29 products, [`comparison.md`](comparison.md) §4), but **its own named
  falsification test was never run** (§8). And red team §4: the most differentiated
  constraint kind (required boundary crossing) is defeated by DI, queues and
  cross-service HTTP — `FACT` 46 queue call sites in potpie, 86 cross-service HTTP sites
  in stakgraph — producing **silent false negatives in a gate**, worse than false positives.
- **C3 adoption 2.** `FACT` (my run) 0/19 use any requirement↔test annotation although
  Xray's `@Requirement` and Allure's `@Issue` are free and years old; 2/19 emit JUnit XML;
  burden is 1,510 `def test_*` in serena and 2,329 in potpie; and 9–10/19 sit below the
  blue team's own substrate threshold.
- **C3 scope 3.** Red team §2 counts ~25 components in the *sellable* v1 against a
  five-item MVC, and [`security.md`](security.md) findings 1–2 make the customer-side
  verifier and trusted-builder `job_workflow_ref` pinning non-optional. "Buildable in
  weeks" — C3's only stated defence in place of a moat — is costed against the wrong artifact.
- **C3 security 5.** I adopt [`security.md`](security.md) §8's mixed verdict: best
  confidentiality posture (no model in the verdict path, nothing executed, smallest TCB),
  worst insider-forgery posture (both inputs head-branch authored and, unlike C2,
  structurally unable to move to the base).

`INFERENCE` **Do not read the C2/C3 ordering as a result.** The 0.3 gap is smaller than
the sensitivity of my weights — moving security defensibility from 10 to 6 flips it. The
honest reading: **all three score below any plausible funding bar, and the ranking among
them is noise.** That, not the ordering, is round 1's output.

## 4. The compounding-advantage gate

Per the ruling: accumulating state, switching cost, proprietary data, or a structural
incentive the incumbent lacks? "An incumbent could build this" is not sufficient — I must
say why they *would*, and what they'd give up.

**C1 — passes this gate, killed on other grounds.** Accumulating state is genuine (graph
plus passport history), but the graph layer is commoditising and the passport is keyed by
a SHA squash-merge may destroy. C1 dies to [`security.md`](security.md) finding 4 and
scope, not to this criterion. **Not a round-2 candidate.**

**C2 — fails the gate.** `INFERENCE` Its best property and its commercial death are the
same property. [`security.md`](security.md) §8 praises it because "its evidence is
re-derivable by anyone from the repo alone — ADR, constraint and query are all in git —
so verification does not require trusting Specera's signature at all." That sentence also
says **nothing accumulates on the vendor's side**: no proprietary data, no retained state,
switching cost equal to a config-format migration. Add measured zero demand. **Killed as a
thesis**; retained as a `criterionType` union member at the one-enum-field cost
[`blue-team.md`](blue-team.md) §1 prices.

**C3 — survives the letter, fails the spirit.** The candidate advantage is the append-only
ledger, which the ruling explicitly permits (`FACT` Rovo's graph truncates at 90 days).
Three things erode it, two of them the red team's answer to the question the ruling
reserved for it: (1) `INFERENCE` [`security.md`](security.md) §4 requires a self-host /
in-region SKU because C3's only plausible buyer is the regulated one — **the deployment
model the buyer requires forfeits the vendor-side accumulation that was the compounding
advantage**; (2) bindings are annotations in customer source, portable by design, zero
lock-in; (3) the retention asymmetry against Xray is not structural — Xray's retention is
Jira's, customer-scoped, and extending it is configuration, not re-architecture.

**Interpreting the Rovo asymmetry, as the ruling requires.** `INFERENCE` Rovo shipped
detection and not evidence for three *incentive* reasons, not capability reasons:
- **Liability.** Detection is advisory prose; evidence is a durable non-repudiable
  assertion that a requirement was tested — over a link [`security.md`](security.md) §2.2
  proves is unverifiable and forgeable for free *by the customer*. Counsel will not sign that.
- **Retention economics.** `FACT` the 90-day TTL is not oversight; indefinite
  per-criterion evidence across Atlassian's install base is a storage and
  data-subject-deletion commitment, not a toggle.
- **Pricing shape.** Detection sells per author at $20/dev/month. A merge *gate* is a
  blocking control sold to platform teams with support load attached; Atlassian
  Premium-gates its own Bitbucket merge checks.

**That is the strongest available argument for C3 — and it does not survive contact with
the right incumbent.** Every asymmetry above is an *Atlassian* constraint. `FACT` Xray is
a test-management vendor whose existing business already consists of retained assertions
about test coverage for regulated customers; it ships `@Requirement`, imports JUnit XML
from CI, records a revision, and computes coverage from executed runs. It has no liability
asymmetry to protect, no retention economics to defend, no per-seat AI pricing model in
the way. **The incumbent that would give something up is Atlassian. The incumbent that
would give up nothing is Xray — and Xray is the one already shipping four of C3's five
steps.** C3 was positioned against the wrong competitor; against the right one there is no
incentive asymmetry at all. **This is the single finding that determines round 1.**

## 5. Ruling on the security go/no-go finding

[`security.md`](security.md) finding 3: no design here can prove a passing test exercises
the criterion it claims.

**Ruling: it kills a claim, not the product — but it kills the claim that carries the
price, and after §4 the surviving claims are ones the buyer can mostly already buy.**

**Not truthful, may not be sold:** "proof to an auditor that this requirement was tested";
"proof that a passing test exercises the criterion it names."

**Truthful and sellable:** (a) a tamper-evident, non-repudiable record of **who asserted**
that test T covers criterion C, in which commit, approved by whom — attribution, not
proof; (b) cryptographic evidence that a named test executed at a named tree digest in a
named trusted builder and exited 0 — provenance of an execution; (c) a merge gate failing
when a linked criterion has no passing bound test at head — a control, not evidence;
(d) retention beyond CI artifact expiry and beyond a 90-day tracker window.

`INFERENCE` Xray supplies weaker (a) and (b) already; (d) is Jira retention; only (c) is
clean — and [`security.md`](security.md) §2.4 requires (c) be a **customer-side verifier**,
or the signing machinery is decorative with respect to the gate. Honest residue: *a CLI
the customer runs, plus a signature format, over a link cryptography cannot secure.*

Finding 3 alone is not a spike no-go ([`security.md`](security.md) says so and I agree).
**With §4 it removes the top of the price and the buyer's reason to switch.** I adopt red
team §8's price ceiling (~$5/dev/month against incumbents at $20–30) and its uncosted
liability inversion — a signed, indefinitely retained, *discoverable* ledger of your own
non-compliance — as a real objection to be sold deliberately, not discovered.

## 6. Verdict — PIVOT

**Not refine.** Refining C3 iterates a proposal whose designated "single most important
unchecked fact" was checked and found false (§4), whose substrate failed its own
pre-committed threshold on the full corpus (§2), and whose sellable v1 is ~5× its stated
MVC. That re-tests a falsified hypothesis.

**Not reject.** Every falsifying measurement is from a 19-repo OSS corpus that is the
wrong reference class **in both directions** (§2): optimistic on test discipline,
pessimistic on CI report formality, silent on enterprise Jira. Rejecting on OSS proxies
repeats exactly the error the blue team is criticised for. Two facts would make reject
safe, neither expensive, neither obtained: what an auditor actually rejects about evidence
a customer already produces with Xray, and whether the criterion↔test binding can be
derived without authoring. [`plan.md`](plan.md) also gates its no-go on "after round 3".

**The pivot, concretely:**
- **C1 rejected as a round-2 candidate** — not merely "as a starting point."
- **C2 killed as a thesis** (§4); retained as a `criterionType` union member; its own
  falsification test deferred to §8's conditions.
- **C3 not carried forward as proposed.** Pivot from *"we produce the evidence"* to *"we
  gate and retain evidence the customer's stack already produces, and we detect the fraud
  cryptography cannot."* Every measurement points one way: **the binding is the scarce
  input and nobody will author it** (0/19, with free alternatives available for years).
  Any product whose value depends on developers authoring bindings is dead in every corpus
  measured. Round 2 must test whether a **zero-authoring** binding exists at usable
  precision, and whether the residue after Xray is worth money.

`INFERENCE` If §7's thresholds come back negative, round 3 is a no-go and the reasoning is
already written. They are fixed now so they cannot be renegotiated later.

## 7. What round 2 must test — executable checks, pre-committed thresholds

Assets: the 19 clones, and `withmartian/code-review-benchmark` (MIT; Sentry, Grafana,
Cal.com, Discourse, Keycloak). `UNVERIFIED` — I did not confirm its licence or corpus.

**R2-1 · Reproduce the ancestry test** (coordinator mandate; unblocks the artifact key).
```bash
gh pr list -R <owner/repo> --state merged --limit 200 \
  --json number,headRefOid,mergeCommit,mergedAt > prs.json
git fetch origin "refs/pull/$N/head":"refs/spike/pr$N"
git merge-base --is-ancestor "$HEAD_OID" origin/HEAD ; echo "$N $?"
```
Over the five benchmark repos plus the 19 clones' upstreams. Report the share of merged
PRs whose head SHA is reachable from the default branch. *Threshold:* <50% →
`subject[0].digest.gitCommit` is the wrong key; re-key on tree digest with mandatory
post-merge re-attestation and price it now. <20% → "SHA-exact", one of only three
surviving differentiators (§5), is unsellable → C3 to reject.

**R2-2 · Enterprise CI reality**, correcting round 1's OSS bias.
```bash
grep -rIlE 'surefire|--junitxml|junit_family|rspec_junit_formatter|jest-junit|\
vitest.*junit|gotestsum|dorny/test-reporter|EnricoMi/publish-unit-test' \
  .github/workflows/ pom.xml build.gradle* Gemfile* package.json 2>/dev/null
```
Over the five benchmark repos (Maven/surefire, RSpec, Go, pytest, vitest). *Threshold:*
≥3/5 already emit or trivially can emit per-test XML → red team §9's "step 0 is a CI
change for ~90% of repos" is an OSS artifact and adoption is materially less bad than
round 1 concluded. ≤1/5 → it stands and adoption is fatal.

**R2-3 · Does a zero-authoring binding exist?** The pivot's crux, testable today. On
`serena` (pytest) and `repomix` (vitest), 100 merged PRs each:
```bash
pytest --cov --cov-context=test --cov-report=json     # serena
vitest run --coverage --coverage.reporter=json        # repomix
# candidate binding: tests whose covered-file set ∩ PR changed-file set ≠ ∅
# ground truth: tests the PR itself added/modified, plus 50 hand-labelled PRs
```
Measure precision@1 and recall of "which existing test covers this change", no annotation
and no model. *Threshold:* precision@1 ≥60% → the pivot has a mechanism, zero authoring
burden, and something Xray does not have. <40% → no zero-authoring product exists, the
annotation burden (verified: 1,510 / 2,329 test definitions) is unavoidable, and §2's 0/19
adoption number is dispositive → reject.

**R2-4 · Forgery detection as a number, not a principle** — most likely to find value. On
`serena`, author 20 `@covers`-annotated tests that pass without exercising their criterion:
`assert True`; over-broad mocks; tests touching no file the PR changed; tests below a
runtime floor. Run [`blue-team.md`](blue-team.md) §5's cheap deterministic flags and
measure detection rate. *Threshold:* ≥80% caught → there is a deterministic, model-free
anti-fraud check nobody in the category ships, and **that** is the differentiator rather
than traceability. <50% → "tamper-evident" is the only honest word available and the
product cannot be priced above a CI plugin.

**R2-5 · Kill or confirm the Xray residue. Documents only, one week, no interviews.** Do
**not** run [`blue-team.md`](blue-team.md) E5's 8–12 interviews yet — four weeks that
answer nothing until the document question is settled. Obtain Xray Cloud REST v2 schemas
for `Test Execution` and `Test Run` and answer in writing: (a) is `Revision` validated
against the SCM or free text? (b) can coverage be computed *by revision*? (c) is there any
GitHub Checks merge-gate integration? (d) what is the retention/deletion policy for Test
Runs? *Threshold:* (a) validated **or** (c) yes → the residue is one item → reject. All
four as the red team predicts → the residue is four items and round 3 earns the interviews.

**R2-6 · Do not manufacture an enterprise substrate number.** Blue-team E1a needs a live
Jira estate the spike does not have. An OSS proxy for a question about enterprise Jira is
the exact error §2 documents. Record enterprise AC parseability as `UNVERIFIED`, state
what would verify it (≥200 work items across ≥3 real projects, deterministic parser only),
and make the round-3 go conditional on it.

## 8. What would have to be true for the rejected concepts to return

**C1.** Returns only as a later phase of something already shipped, never as a starting
point, and only if all three hold: (i) the MVC is redefined to *consume* CI output rather
than execute repo commands, closing [`security.md`](security.md) finding 4; (ii) a
cross-repository impact set is measured against ground truth from real incidents at a
stated precision, not asserted; (iii) predicted-vs-actual impact is demonstrated on at
least one real deploy. Absent (ii) it is a bet whose failure is silent and late.

**C2.** Killed on demand evidence while **its own named falsification test was never run** —
nobody measured what fraction of real constraints a free linter already expresses. That is
a defect in round 1, so the kill is reversible. C2 returns if both hold: (i) a buyer
segment is identified where ADR density is structurally non-zero because a *regulator*
mandates design records — automotive ISO 26262, medical IEC 62304, aerospace DO-178C —
precisely the population where "0/19 OSS repos" does not generalise; **and** (ii) its own
test is then run on that segment's repos, with ≤50% of useful constraints expressible by a
free linter. Condition (i) also supplies the enforcement mandate and the budget
[`product-concepts.md`](product-concepts.md) concedes it lacks, so the two are one search.

**C3 as originally framed** ("proof to an auditor that this requirement was tested") does
not return. [`security.md`](security.md) finding 3 is not a scheduling problem; no
mechanism here or in any competitor closes it, and marketing it sells an audit-fraud
instrument. Only the attribution framing in §5(a)–(d) may be pursued.

## 9. Where I may be wrong

1. **The C2/C3 ordering is not robust** (§3) — stated rather than presented as a rank I
   cannot defend.
2. **I did not reproduce the ancestry test**, and carry SHA-rewriting as `UNVERIFIED`
   despite it being load-bearing for the artifact key. R2-1 exists because of this.
3. **My reading of the Rovo/Xray incentive asymmetry (§4) is `INFERENCE`** — built on
   verified facts, not itself verifiable. It is the reasoning most worth disagreeing with,
   and the whole verdict turns on it. If R2-5 comes back the red team's way on all four
   points, §4 weakens and refine becomes arguable again.
4. **I have no enterprise data at all.** Every number is OSS. §2 argues the bias runs in
   opposite directions on the two adoption metrics; that is `INFERENCE`, and R2-2 tests
   half of it.
