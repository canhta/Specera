# Red team — the case against building

Agent A3, round 1, 2026-08-04. Independent. Input: [`product-concepts.md`](product-concepts.md),
[`blue-team.md`](blue-team.md), [`comparison.md`](comparison.md), [`sdlc-model.md`](sdlc-model.md),
[`security.md`](security.md), and the 19 clones in `.spike/clones/`. Labels per [`plan.md`](plan.md).
Mechanism-level security belongs to [`security.md`](security.md); §7–§8 take only the commercial
angle. Where a claim could be measured, I measured it; commands are inline and re-runnable.

## 0. Verdict

| | C1 Change Assurance | C2 Executable Architecture | C3 Acceptance Evidence |
|---|---|---|---|
| Verdict | **Kill** as a starting point | **Kill** as a company | **Wounded — survivable at ⅓ scope and a reduced claim** |
| Fatal finding | §2 scope; §5b; [`security.md`](security.md) finding 4 (RCE in the MVC) | §1: 0/19 repos have an ADR **and** 0/19 configure any free arch linter | §1: the differentiating claim is factually wrong about the real incumbent |

`INFERENCE` The proposal is unusually honest — [`blue-team.md`](blue-team.md) §10 pre-concedes most
of what a lazy red team would "find". My contribution is three measured refutations it does not
contain: the substrate rate is worse than reported because the sample was truncated (§6), the
merge-strategy assumption fails on two-thirds of real repos (§5a), and the competitor the concept is
positioned against already ships the mechanism (§1).

---

## 1. Differentiation — the strongest attack, and it is a fact

[`blue-team.md`](blue-team.md) Claim B: *"a named existing budget line exists, and what it buys is a
**manually asserted** link with no execution proof."* Labelled `UNVERIFIED`, and called the single
most important unchecked fact in the proposal. I checked it. **It is false in the form C3 needs.**

- `FACT` `Xray-App/xray-junit-extensions` (EPL-2.0) ships `@Requirement("CALC-1234")`, binding a
  JUnit test method to a Jira issue and emitting it as JUnit-XML metadata. That is C3 step 2, free.
- `FACT` Xray imports JUnit/xUnit XML from CI via REST v2 (`docs.getxray.app`, *Import Execution
  Results – REST*). Step 3.
- `FACT` Xray's `Revision` field on a Test Execution is documented as "the system revision (or code
  revision) being tested … an open field that can contain the Git commit hash" (`docs.getxray.app`,
  *Using custom fields* / *Test Execution*). Step 3's commit key.
- `FACT` Xray Coverage Analysis computes requirement coverage **from executed Test Executions**,
  analysable by Version / Test Plan / Environment / Latest
  (`docs.getxray.app/space/XRAYCLOUD/44565185`). Step 4 minus the gate.
- `FACT` 25,849 installs, "over 10,000 companies" (Atlassian Marketplace listing 1211769).

`INFERENCE` The pitch "they store a manually asserted link, we store execution proof" is therefore
unavailable. C3's buyer already has annotation → CI import → execution-backed requirement coverage,
in their existing estate, on a budget line they already pay.

**What genuinely survives, narrowly:** (a) Xray's coverage dimensions are Version / Test Plan /
Environment — **not** revision, and `Revision` is unvalidated free text, so it is a label, not a key;
(b) no merge gate on GitHub; (c) no signing, transparency log or non-repudiation; (d) retention is
Jira's, not append-only by design. `INFERENCE` A real but thin residue: Specera is not "requirement
traceability", it is a *SHA-exact, merge-gating, cryptographically retained layer over a traceability
product the customer already owns*. That is a feature of Xray.

**One quarter?** `FACT` GitHub shipped ruleset-based **coverage merge protection** — block a PR when
coverage drops below a threshold — on 2026-06-30, public preview, Enterprise Cloud + Team
(github.blog changelog). `FACT` Rovo Dev acceptance-criteria checks are GA on Rovo Dev Standard
(`support.atlassian.com/rovo`). `INFERENCE` The gate primitive is now a GitHub ruleset feature and
AC-comparison an Atlassian GA feature; Xray's remaining work to close (a)–(d) is to validate its
Revision field against the SCM and post a GitHub check. **[`plan.md`](plan.md)'s kill criterion — "no
differentiator survives that a competitor cannot ship in one quarter" — holds against C3 on measured
evidence, not conjecture.**

**Wounds C3 badly**, short of an outright kill only because the incumbents demonstrably have not
shipped it and [`blue-team.md`](blue-team.md) §10 never claimed a moat. **Fix:** stop positioning
against Rovo/GitLab — their weakness is real but their buyers are not C3's. Position against
**Xray/Zephyr**, where the honest claim is narrower and testable: SHA-exactness, merge gating,
non-repudiation, retention. E5 then becomes "will an auditor pay for those four given they already
run Xray?" — sharper and cheaper than what is currently scheduled for weeks 6–10.

---

## 2. Excessive scope — the MVC is the maximal version wearing a small hat

[`product-concepts.md`](product-concepts.md) C3's MVC is five things. [`blue-team.md`](blue-team.md)
then specifies the actual v1: a bitemporal append-only ledger with `valid_at`/`invalid_at`
supersession; Sigstore keyless + Fulcio + Rekor + DSSE + in-toto v1; **three** storage copies (git
notes, release assets, OCI referrers) plus Postgres; a six-step customer-side `specera verify` with
replay in a pinned runtime image; **ten** deterministic checks; a node-id canonicaliser across
pytest/JUnit5/jest/vitest/gotestsum (its own "sharpest unpriced risk"); per-language tree-sitter
extractors; a waiver workflow with a named second approver; policy-integrity with CODEOWNERS; SARIF
ingest. [`security.md`](security.md) adds mandatory trusted-builder `job_workflow_ref` pinning
(finding 2), redaction on ingest, and a self-host SKU (§4).

`INFERENCE` ~25 components, not five. "Buildable in weeks" and the time-to-market defence — *the only
thing this concept has instead of a moat* — rest on the five-item version, and E2's kill criterion
exercises only that version, so **the 90-day plan structurally cannot detect that the sellable
product is 5× the MVC.** That is a flaw in the proof plan, not only the product.

**Wounds C3. Fix:** re-scope E2 to the *sellable* v1 — including trusted-builder pinning and the
customer-side verifier, which [`security.md`](security.md) findings 1–2 make non-optional. If that
does not fit in three weeks, the time-to-market defence is gone and §1 becomes fatal.

---

## 3. Graph accuracy and freshness

C3 has no graph. **This is sound and I will not manufacture an attack on it.** For C1 (total
dependence) and C2 (substantial), [`comparison.md`](comparison.md) Gap 1 — confidence computed then
ignored — is real but is a `WHERE` clause. `INFERENCE` A differentiator that is one predicate is a
bug fix the named engines ship in a sprint, not a moat. **Neutral for C3, compounding for C1/C2.**

---

## 4. Dynamic and cross-repository dependencies

```bash
grep -rIl --include='*.py' -E 'importlib\.import_module|__import__\(|getattr\(|globals\(\)\[|entry_points\(' <repo>
grep -rIl --exclude-dir=node_modules -iE 'celery|rabbitmq|kafka|sqs|pubsub|bullmq' <repo>
```

`FACT` Files with dynamic-dispatch constructs: potpie 92/773 Python files, codegraphcontext 34,
graphify 20, aider 14; TypeScript dynamic `import()`/`require()`: sourcebot 36, stakgraph 34,
repomix 20. `FACT` Message-queue call sites: potpie 46 files, sourcebot 12. Cross-service HTTP call
sites: stakgraph 86, sourcebot 34.

`INFERENCE` C2's third constraint kind — *required boundary crossing* ("any call from `api/**` to
`db/**` must pass through `repository/**`") — is exactly what a DI container, a queue hop or an HTTP
call between services makes invisible to a static resolver. The constraint then **passes while the
boundary is violated**. Silent false negatives in a gate are worse than false positives: they convert
"we don't know" into a signed "conformant". C2's falsification test measures true positives on found
violations and never the false-negative rate, which is the one a gate lives on. **Wounds C2's most
differentiated constraint kind. Fix:** ship only forbidden-dependency and layer-ordering in v1 (both
statically decidable); mark boundary-crossing constraints `evidence_strength: inferred` so they
cannot gate.

---

## 5. Migrations, rollback, and rewritten history

### 5a. Squash and rebase destroy the key the design uses

```bash
git log --first-parent -n 300 --format=%s | grep -cE '\(#[0-9]+\)$'                    # squash signature
git log --first-parent --no-merges -n 300 --format='%at %ct' | awk '$1!=$2' | wc -l    # rebase proxy
```

`FACT` 9/19 clones are squash-dominant (≥50% of first-parent commits carry a `(#N)` subject, near-zero
merge commits): potpie 99%, GitNexus 98%, zoekt 97%, bloop 95%, codegraph 86%, stakgraph 86%,
sourcebot 65%, gitingest 64%, deepwiki-open 64%. `FACT` Four more are rebase-heavy (author ≠ committer
date on >40% of first-parent non-merge commits): opengrok 75%, claude-context 53%, serena 45%,
graphify 40%. **13 of 19 repos (68%) rewrite commit SHAs at merge.**

Executed demonstration:

```
PR head SHA (attested): 8436daae…      mainline SHA after squash: 1bc26672…
git merge-base --is-ancestor <head> HEAD  → NO: attested SHA is not an ancestor of mainline
after `git gc --prune=now`                → GONE: git cat-file cannot find the attested commit
```

`FACT` The attested commit is unreachable from mainline and is collected. On GitHub it survives only
in `refs/pull/N/head`, which a normal clone does not fetch and a release tag does not reach.
[`security.md`](security.md) §2.3 identifies this; its own mitigation — *"assemble the release bundle
only from commits reachable from the tag, refusing artifacts whose SHA is unreachable"* — therefore
means **a correctly configured Specera reports "no evidence" for every release in 68% of repos.**
[`blue-team.md`](blue-team.md) §4 makes `mergeSha?` optional; optional is wrong for the majority case.

**Partial fix, measured.** Key on **tree digest**, not commit SHA:

```
attested head TREE b7545cc4…  ==  squashed mainline TREE b7545cc4…   SAME
base moves first:  attested f1b7144a…  vs merged 2058f35b…           DIFFERENT
```

`FACT` A squash onto an *unmoved* base yields an identical tree, so tree-keying survives it for free;
when the base moves it does not. `INFERENCE` Tree-keying rescues the up-to-date-branch case; the
moved-base case still needs **mandatory** post-merge re-attestation, doubling gate cost — a price
that must be set now, not later.

### 5b. Migrations: nobody can roll back, and the evidence never says so

```bash
find sourcebot/packages/db/prisma/migrations -name 'down.sql' | wc -l   # 0
```

`FACT` Zero down-migrations across the whole corpus: 0/87 Prisma SQL files in sourcebot, 0/17 in
bloop, 0/1 in codegraph. Migrations are forward-only in practice.

`INFERENCE` A release rollback therefore reverts code but not schema. The Evidence Statement asserts
test `T` passed at commit `X`; after rollback, production runs code `X` against schema `N+1` — a
configuration **no recorded run ever exercised**. [`blue-team.md`](blue-team.md) §4's schema has no
field for migration state; `subject[0].digest.gitCommit` describes code only. The artifact is
confidently silent about the commonest cause of "green in CI, broken in prod", and for an audit
artifact silence that reads as assurance is the worst available failure mode. `FACT` Migration files
are also edited after being committed — 9 post-commit modifications in codegraph, 3 in bloop — so
even a blob digest over the migration directory is unstable.

**Wounds C1 and C3. Fix, cheap:** put a migration-head identifier in the statement subject and refuse
to count a passing run toward a release whose migration head differs. One field and one comparison,
converting a silent wrong answer into a visible `not-applicable`.

---

## 6. Missing tests — I do not reproduce ~45%

Re-ran the blue team's measurement independently (`scratchpad/testtouch.sh`: per repo, the last 400
non-merge commits touching a source extension, share also touching a test path).

`FACT` I reproduce their nine numbers within a point — graphify 89, codegraph 88, repomix 62, serena
45, codegraphcontext 44, potpie 34, gitdiagram 34, aider 28, deepwiki-open 3. **The method
replicates. The sample does not.**

`FACT` The ten clones [`blue-team.md`](blue-team.md) §2 does not report: GitNexus 96, grepai 64,
zoekt 51, opengrok 50, stakgraph 33, gitingest 30, sourcebot 24, code2prompt 16, claude-context 15,
bloop 1. `FACT` **Median over all 19 = 34%, not 45%.** Median of the ten omitted = 31.5%. **10 of 19
repos fall below 35%.**

`INFERENCE` [`blue-team.md`](blue-team.md) §9 pre-commits E1b's kill at "<35% in a majority of
repos". **On the corpus the blue team itself used, a majority of repos are already below its own
threshold** — and it separately states this corpus is an *optimistic* reference class for enterprise.
I do not allege cherry-picking (the nine reported are the SDLC-relevant ones); the effect of the
truncation is nonetheless to report the flattering half.

**At 10%.** In bloop (1%), deepwiki-open (3%), claude-context (15%), `specera/coverage-gate` is red
on essentially every PR. There is no false-positive problem — there is no model — there is a
**total-blockage** problem, whose equilibrium is the §7 waiver path. `INFERENCE` A ledger whose
dominant verdict is `waived` is the compliance ornament
[`product-concepts.md`](product-concepts.md) warns about for C1, arriving through another door.

**One genuine false-positive generator exists.** `specera/annotation-resolution` fails on dangling
`@covers`, and `textDigest` is designed to invalidate rows when criterion text changes — so a PM
fixing a typo in a Jira AC turns unrelated PRs red. `INFERENCE` Non-engineering trigger, blame on the
tool: the classic path by which a required check is demoted to advisory. **Fix:** text drift must
produce `verdict: stale` surfaced on the *work item*, never a red gate on an unrelated PR.

---

## 7. Permissions — affordability, not mechanism

[`security.md`](security.md) §3 has the scopes; the commercial question is what the ask looks like on
a procurement form. `INFERENCE` C3's honest onboarding is four asks: (1) a GitHub App with
`checks:write` — which [`security.md`](security.md) §3 correctly classes as a *production-control*
capability, the power to block every merge in the org; (2) `write:jira-work` for AC-id write-back;
(3) adoption of an org-owned pinned reusable workflow (finding 2), a platform-team project rather
than a developer opt-in; (4) annotating tests. Xray's onboarding: install from Marketplace, add one
REST call, data never leaves Atlassian.

`INFERENCE` Ask (1) is not a security *refusal* — teams grant `checks:write` to CodeRabbit today —
it is a **procurement duration** problem: a merge-blocking third-party App in a regulated shop is a
vendor-risk review, not a credit card. The facts interact badly — the segment chosen *because* it
cares about evidence is the slowest to grant the permission the evidence needs, and time-to-market is
C3's only defence. **Costs months of sales cycle; not a kill. Fix:** ship a CLI-first mode inside
customer CI with no App and no Jira write ([`security.md`](security.md) §3 notes C3's MVC needs no
source access). Sell the gate later.

---

## 8. Forged evidence — what it does to the price

[`security.md`](security.md) finding 3 is a no-go against a *claim*: `def test_ac2(): assert True`
plus `@covers` yields a valid, signed, replayable green gate, cheaper than doing the work. The
product consequence is mine to draw: **the value proposition and the price both sit on the wrong side
of that line.** The auditor asks "was this requirement tested?"; Specera answers "someone named
asserted it was, and a named execution occurred". `INFERENCE` Willingness to pay for
*non-repudiation of an assertion the audited party makes about its own work* is far below
willingness to pay for *proof* — and per §1 the buyer already owns the traceability layer, so what
remains for sale is the non-repudiation alone, over precisely the link cryptography cannot secure.
Hard to price above ~$5/dev/month against incumbents charging $20–30.

`INFERENCE` An uncosted liability inversion: a signed, indefinitely retained ledger is
*discoverable*. A customer who adopts Specera and later fails an audit has produced, signed and
retained the evidence of its own non-compliance — a real reason general counsel says no, and the same
property that makes the product valuable. It must be sold deliberately, not discovered.

**Caps C3's price and narrows its claim; not a kill.** [`security.md`](security.md)'s framing —
*tamper-evident, non-repudiable, execution-backed attribution* — is the sellable one, and must now
also concede that Xray already supplies the execution-backed half.

---

## 9. Adoption — the honest curve, measured

The most likely fatal challenge and the least examined.

`FACT` **Zero repos use any requirement↔test annotation convention.**
`grep -rIlE '@covers|@requirement|@testcase|allure\.link|allure\.issue|@Issue\(|pytest\.mark\.(requirement|jira|ticket)'`
across all 19 clones returns nothing. Allure's `@Issue`/`@link` and Xray's `@Requirement` are years
old and free; adoption here is nil.

`FACT` **17 of 19 repos emit no JUnit XML from CI at all.** Grepping 158 workflow files for
`junit|test-results|--junitxml|dorny/test-reporter` hits only GitNexus (3/29) and repomix (2/19). So
"we consume the customer's existing CI results" is not free — for ~90% of repos, step 0 is a CI
change before any value appears. Note that both E2 pilot repos (serena, repomix) start further back
than assumed.

`FACT` **Work-item keys are not in the commits.** Jira-shaped keys appear in a median ~1% of the last
300 non-merge commits per repo (only sourcebot 40%, potpie 18% material). `specera/work-item-
resolution` leans on branch / trailer / PR-body signals instead; `UNVERIFIED` for enterprise estates
with branch conventions — but unverified, and the concept's first check depends on it.

`FACT` **Annotation burden is large:** serena 1,510 `def test_*`; potpie 2,329; repomix 1,644
`it()/test()`; opengrok 1,315 `@Test`; zoekt 441 `func Test*`.

`INFERENCE` **The curve.** Day 1: gate installed, zero annotations, red on every PR with a linked
work item. Days 2–30: teams annotate only what the gate blocks, so annotation coverage tracks the
share of PRs touching a test — median 34% (§6) — and the rest take the waiver. Steady state: a
release rollup reading "42 criteria: 14 proved, 9 unproved, 19 waived". **That artifact is worse than
useless to an auditor — it is an itemised, signed, non-repudiable list of what you failed to test.**
The proposal never says what the artifact means at partial coverage, and partial coverage is the only
state it will ever occupy.

**This, not the moat, is what kills C3 in the field. Fix, and it is a real one:** invert the default.
Do not gate on *criteria without tests*; gate on *regressions in the proved set* —
`specera/coverage-delta` already exists in [`blue-team.md`](blue-team.md) §5 and is the only check
green on day one, monotonically improving, and never blocking work that was already unproved.
Ratchets get adopted; cliffs get waived.

---

## Which concept I would fund

**C3, at roughly a third of the proposed scope, reframed.** Fund: annotation extractor, JUnit/CI
collector with node-id canonicalisation, append-only ledger, `coverage-delta` as the default gate,
customer-side verifier. Do **not** fund in v1: Sigstore/Rekor/in-toto, three storage copies, replay,
SARIF binding, waiver workflow, Jira write-back, criterion-segmentation LLM, binding-suggestion LLM.
Retarget from Rovo/GitLab to Xray/Zephyr; restate the claim from "proof" to "SHA-exact, merge-gating,
retained attribution".

**Do not fund C1 as a starting point.** [`security.md`](security.md) finding 4 (RCE from an untrusted
repo *inside* the minimum viable core), plus §2 scope, plus §3 total graph dependence: a
runway-consuming bet whose failure is silent and late — the exact failure
[`product-concepts.md`](product-concepts.md) names for it.

**Do not fund C2 as a company.** The uncontested-stage finding is real and its security posture is
the best of the three ([`security.md`](security.md) §8 is right about base-branch evaluation). But
`FACT` 0/19 repos contain a `docs/adr/` directory, an `adr-NNN.md`, or any decision record; **and**
0/19 configure any architecture linter (dependency-cruiser, import-linter, `no-restricted-imports`,
boundaries) though all are free. `INFERENCE` The second number is the damning one: C2's own
falsification test asks whether a free linter *could* express the constraints, and the measured
answer is that nobody uses the free linter that already can. Zero competitor coverage is not an open
market — here it is measured absence of demand. Fund it as a module on request, never as the thesis.

## Single strongest kill shot

**Specera sells cryptographic assurance over the one link in the chain that cryptography provably
cannot secure, to a buyer who already owns the rest of the chain.**
[`security.md`](security.md) §2.2 establishes that the `@covers` binding is an unverifiable assertion
by the audited party about its own work, forgeable for free. §1 establishes by primary documentation
that the annotation → CI import → execution-backed requirement coverage pipeline is already shipped
by Xray at 25,849 sites, with a documented commit-hash field. Remove what Xray already supplies and
what cryptography cannot secure, and the residue for sale is *a merge-blocking GitHub check and a
longer retention window*. The proposal has no answer, because it was written against the wrong
competitor: [`blue-team.md`](blue-team.md) §2 flags Claim B as the most important unchecked fact, and
when checked it does not hold.

## What I could not test

1. **Enterprise substrate.** Every rate here is OSS. E1a — are real Jira ACs machine-parseable? —
   needs a live estate and is the largest remaining unknown.
2. **Whether an auditor accepts Xray today.** E5 is still right; §1 changes its question from "is
   there a budget line?" (yes, 10,000 companies) to "what would fail an audit about what Xray already
   produces?".
3. **False-negative rate for C2's boundary constraints** — needs a resolver and hand-labelled ground
   truth. I bounded the dynamic-dispatch surface, not the miss rate.
4. **Whether `refs/pull/N/head` retention makes squash survivable on GitHub in practice** — needs a
   live org; my demonstration covers local reachability only.
5. **Node-id canonicalisation for jest/vitest**, [`blue-team.md`](blue-team.md) §3's own sharpest
   unpriced risk. I confirmed neither pilot repo emits JUnit XML at all; I did not attempt it.
