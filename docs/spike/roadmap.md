# Roadmap — phases, metrics, kill criteria

**This roadmap is conditional.** Round 1 returned **pivot** with no concept above
4.1/10 ([`evaluation.md`](evaluation.md)). Phase 0 is therefore a set of kill
tests, not a build. `INFERENCE` If phase 0 fails, no later phase is authorised —
the correct output is a no-go, recorded in [`decision.md`](decision.md).

Do not read this as a plan to build. Read it as the cheapest ordering of the
experiments that would justify building.

## Phase 0 — kill tests (weeks 0–3, no product code)

Every test below has a pre-committed threshold. `INFERENCE` The point of
committing thresholds in advance is that round 1 demonstrated the failure mode:
the blue team set a ≥35% substrate threshold, then measured a sample that passed
it, and the full corpus failed it (32–34% median, 9–10 of 19 repos below —
[`.spike/verification-coordinator.md`](../../.spike/verification-coordinator.md)).

| # | Test | Method | Kill threshold |
|---|---|---|---|
| 0.1 | **Xray residue** | Documentation only, ≤1 week. Is Xray's `Revision` SCM-validated? Coverage by revision? Any merge gate? Retention and tamper-evidence? | Any blocking gate exists, **or** `Revision` is validated → **no-go on the pivot** |
| 0.2 | **Zero-authoring binding** | Derive criterion↔test from per-test coverage contexts (`pytest --cov-context=test`, `vitest --coverage`) ∩ PR changed files. 100 merged PRs each in two repos | precision@1 < 40% → adoption cannot be designed away → **no-go** |
| 0.3 | **SHA survival** | `git merge-base --is-ancestor <pr head sha> origin/HEAD` over API-sourced merged PRs, ≥8 repos × ≥20 PRs | Settles 13/19 vs 6/19. Informs keying, does not kill by itself |
| 0.4 | **Enterprise substrate** | The OSS corpus is an optimistic reference class for tests and a pessimistic one for CI reporting. Measure in 2–3 real Jira+GitHub estates | < 35% of merged PRs touch tests → substrate claim fails |

`INFERENCE` 0.1 is first because it is the cheapest and the most likely to end the
project. Spending three weeks on 0.2 before reading Xray's documentation would be
the expensive way to learn the same thing.

**Phase 0 exit:** all four pass → phase 1. Any kill threshold hit → no-go.
Ambiguity is not a pass.

## Phase 1 — thinnest credible slice (weeks 3–12)

Only if phase 0 passes. Scope is the red team's one-third, not the blue team's
proposal: annotation extractor, CI collector, append-only ledger,
**`coverage-delta` as the default gate**, and a customer-side verifier.

`FACT` Explicitly cut, per [`red-team.md`](red-team.md) and
[`security.md`](security.md): Sigstore/Rekor (the public-log identity leak in
[`security.md`](security.md) §2.5 is unresolved), triplicate storage, replay,
SARIF, waivers, Jira write-back, and both LLM paths.

`INFERENCE` The gate must default to **delta** — "this PR did not reduce
criterion coverage" — not absolute coverage. An absolute gate fails on day one in
a repo at 32% test-touch and gets disabled, and a disabled gate produces no
evidence at all.

| Metric | Target | Meaning |
|---|---|---|
| Time to first evidence | < 1 CI run after install | The one advantage over graph-based concepts |
| Gate still enabled at day 30 | > 80% of pilots | A disabled gate is a dead product |
| Binding coverage without authoring | > 40% | From 0.2; if this needs hand annotation, adoption governs |
| False-block rate | < 2% | Above this, teams add a bypass and the gate is theatre |

**Phase 1 kill criteria:** any pilot disables the gate and declines to re-enable ·
false-block > 5% · binding coverage collapses below 25% on real repos.

## Phase 2 — compounding advantage (months 3–9)

Only if phase 1 holds. `INFERENCE` This phase exists because
[`plan.md`](plan.md)'s amended kill criterion is not satisfied by phase 1: a
merge gate plus retention is a head start, and time-to-market is explicitly not
a moat under that ruling.

The only candidate compounding assets identified in round 1:

1. **Accumulated evidence with retention guarantees.** `FACT` Rovo's Teamwork
   Graph discards history after 90 days. `UNVERIFIED` whether that is durable or
   a current product gap — phase 0.1 partly answers it for Xray.
2. **Cross-tracker, cross-repo evidence** that neither Atlassian nor GitHub can
   assemble because each sees only its own half. `INFERENCE` This is the one
   asymmetry a single vendor cannot close by shipping a feature.
3. **A second `criterionType`** — the ADR constraint from Concept 2 — reusing the
   same ledger, signing, gate, and verifier. `FACT` 0/19 clones contain an ADR, so
   this is a bet on creating demand, not serving it.

**Phase 2 kill criterion:** if by month 9 the answer to "what do we have that a
competitor could not ship in a quarter" is still only retention, stop. That is
the amended criterion applied honestly.

## What is deliberately not on this roadmap

`FACT` Rejected in round 1 with evidence, not deferred:

- **Concept 1 / Change Passport** — 2.8/10; RCE inside its own MVP
  ([`security.md`](security.md)); depends on a graph layer that
  [`comparison.md`](comparison.md) §1 shows is six months old and commoditising.
- **Concept 2 as a company** — 4.1/10; 0/19 repos have an ADR *and* 0/19 configure
  a free architecture linter, which is measured absence of demand.
- **Building a graph engine, a scanner, or a code-search tier.** Integrate zoekt
  (Apache-2.0) and serena `solidlsp` (MIT) if ever needed; the licence verdicts in
  [`comparison.md`](comparison.md) §5 are binding.
- **Any claim of the form "proof that this requirement was tested."**
  [`security.md`](security.md) establishes it is unprovable and that selling it
  would be an audit-fraud instrument. This is a permanent constraint on
  positioning, not a phase.
