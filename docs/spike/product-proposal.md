# Product proposal — the surviving concept, at surviving scope

**Status: conditional and unfunded.** Round 1 scored every concept below a
funding bar ([`evaluation.md`](evaluation.md): 2.8 / 4.1 / 3.8 out of 10) and
returned **pivot**. This document states what remains defensible *if* the phase-0
kill tests in [`roadmap.md`](roadmap.md) pass. It is not a recommendation to
build today. The go/pivot/no-go call is in [`decision.md`](decision.md).

## 1. Selected concept

**Concept 3, Executable Acceptance Evidence — pivoted and reduced.**

`INFERENCE` Selected by elimination rather than merit. Concept 1 scored 2.8 and
carries remote code execution inside its own minimum viable product
([`security.md`](security.md)). Concept 2 fails the compounding-advantage gate
because its evidence is re-derivable from the repository without the vendor —
which is the same sentence as "nothing accumulates on the vendor side" — and
`FACT` 0 of 19 clones contain an ADR *or* configure a free architecture linter.
Concept 3 survives the letter of the gate and fails its spirit. The C2/C3 ordering
is a 0.3 gap and is **not robust**; the honest reading is that none of the three
earned funding, and C3 is merely the cheapest to disprove.

**The pivot, stated precisely.** Round 1 aimed C3 at Atlassian and GitHub. That
was the wrong target. `FACT` Rovo ships requirement *detection* and not
*evidence*, and that asymmetry is explainable by Atlassian's own constraints —
liability over an unverifiable link, 90-day retention economics, per-author
pricing that resists a blocking control. `FACT` Xray has none of those
constraints and already ships four of C3's five steps: `@Requirement("KEY-123")`
as a free EPL-2.0 JUnit annotation, JUnit XML import from CI, a `Revision` field
for the git commit, and coverage computed from executed runs
([`.spike/verification-coordinator.md`](../../.spike/verification-coordinator.md) §3).
The competitor is Xray and Zephyr Scale, not Rovo and Duo.

## 2. What may be claimed, and what may not

`FACT` [`security.md`](security.md) establishes that no design in this spike — or
in any competitor's — can prove that a passing test exercises the criterion it
claims to cover. `def test_ac2(): assert True` plus a `@covers` annotation yields
a valid, signed, reproducible green gate, and the forgery is cheaper than
compliance.

| May be sold | May **not** be sold |
|---|---|
| Tamper-evident attribution: *who* asserted that this test covers this criterion | "Proof that this requirement was tested" |
| Provenance of an execution: this named test ran, at this commit, in this run | "Audit-grade verification of requirement coverage" |
| A merge gate that blocks when the record is empty | Any claim implying semantic correspondence between test and criterion |
| Retention beyond the incumbents' windows | Compliance attestation |

`INFERENCE` This is the central commercial problem, not a footnote: the claim
that carries the price is the one that cannot be made truthfully. A product sold
on the left column is a workflow tool competing with Xray on convenience. Selling
the right column would be an audit-fraud instrument.

## 3. Architecture, at reduced scope

Five components. `FACT` Everything else in the round-1 proposal is cut per
[`red-team.md`](red-team.md) and [`roadmap.md`](roadmap.md) phase 1.

1. **Criterion extractor** — segments individually addressable acceptance criteria
   from Jira work items into stable `KEY.AC-n` identifiers. Deterministic parsing,
   no model.
2. **Binding resolver** — associates criteria with tests. `INFERENCE` The design
   hinges on this being derivable *without* developer annotation, via per-test
   coverage contexts (`pytest --cov-context=test`, `vitest --coverage`)
   intersected with PR-changed files. `FACT` 0/19 clones use any requirement↔test
   annotation today, so an annotation-dependent design is an adoption bet the
   evidence does not support. Phase-0 test 0.2 decides this.
3. **CI collector** — ingests JUnit XML and coverage output, records test node id,
   outcome, run id, artifact digest, and commit.
4. **Append-only ledger** — the evidence store. Keyed by `(work item key, commit
   SHA)` with a **tree-digest fallback**, because `UNVERIFIED` between 6/19 and
   13/19 of repositories rewrite the head SHA at merge, orphaning any artifact
   keyed to it alone.
5. **Customer-side verifier** — the required status check. `FACT`
   [`security.md`](security.md) §2.4: a GitHub required check trusts the API call
   that sets it, not any signature, so a vendor-posted check is decorative with
   respect to merge permission. The gate must be a verifier running in the
   customer's CI against a customer-held trust root.

**Integrate, do not build** ([`comparison.md`](comparison.md) §5 licence verdicts
are binding): zoekt (Apache-2.0) and serena `solidlsp` (MIT) if a symbol layer is
ever needed; Jira's **Builds API** (`/rest/builds/0.1/bulk`, which carries the
typed `testInfo` object) for writing outcomes back — *not* the Development
Information API, which carries branches, commits, and PRs only.

**Explicitly excluded:** Sigstore/Rekor — `FACT` [`security.md`](security.md) §2.5
shows the keyless-identity fix and the public-log fix conflict, because a Fulcio
certificate embeds the CI OIDC subject containing the repository path, so a public
log emits a timestamped feed of private repository names. Publicly verifiable,
non-repudiable, confidential: pick two, and say which two.

## 4. The gate

`INFERENCE` **Default to coverage-*delta*, not absolute coverage.** At a measured
32–34% median test-touch rate with 9–10 of 19 repositories below 35%, an absolute
gate fails on installation day, gets disabled, and then produces no evidence at
all. A delta gate — "this change did not reduce criterion coverage" — is
enforceable in a repository that starts at 20%.

Human approval gates remain per [`sdlc-model.md`](sdlc-model.md): the gate blocks
on an *empty record*, never on a model's judgement of quality. No LLM is in the
enforcement path in phase 1.

## 5. Greenfield versus maintenance

`INFERENCE` Phase 1 targets **maintenance** on GitHub + Jira estates that already
run CI with JUnit-format output. Greenfield waits: [`sdlc-model.md`](sdlc-model.md)
§3 establishes they are different lifecycles with different cold-start problems,
and the greenfield entry ritual is a second onboarding product. Building both is
two roadmaps and should not be assumed free.

## 6. What would make this a real product

`FACT` Per [`plan.md`](plan.md)'s amended kill criterion, a merge gate plus
retention is a head start, and time-to-market is explicitly not a moat. The only
candidate compounding asset identified in round 1 that a single vendor cannot
close by shipping a feature is **cross-tracker, cross-repository evidence** —
Atlassian sees Jira, GitHub sees code, and neither sees both. Everything else on
this page is convenience that Xray could match.

`INFERENCE` If phase 0 shows Xray already validates its `Revision` field or offers
any blocking gate, the residue is empty and the correct answer is no-go. That
test costs one week of reading documentation and should be run before anything is
built.
