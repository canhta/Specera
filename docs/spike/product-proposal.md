# Product proposal — Specera, an open-source SDLC knowledge graph

**Target, as re-specified by the sponsor after round 2:** Graphify's mechanism —
deterministic extraction, provenance on every edge, MCP-queryable, no vector
store — applied to the **whole product lifecycle** rather than code alone. Open
source. The single source of truth and governance centre for SDLC data, for
agents and humans, across Jira, Confluence, GitHub, Gherkin, Grafana and MCP.

Verdict: **conditional go** ([`decision.md`](decision.md) §7). The earlier no-go
in §1–§5 applies to the evidence/gate/compliance products of rounds 1–2 and does
not apply here.

## 1. The architectural decision that governs everything else

`INFERENCE` Specera is the source of truth for **edges**, not for **nodes**.

[`sdlc-model.md`](sdlc-model.md) fixes Jira as the system of record for work and
requirements and GitHub for code, PR and release. A product that tries to *own*
tickets fights Jira, loses, and spends its life on two-way sync, write conflicts
and drift — the standard death of a "single pane of glass".

| Layer | Owner | Specera's role |
|---|---|---|
| Ticket, epic, acceptance criterion | Jira | mirror + reference, with provenance and freshness TTL |
| Code, PR, merge commit, release | GitHub | mirror + reference |
| Metric, alert, incident | Grafana / on-call tooling | mirror + reference |
| Feature file, scenario, step | the repository | **parse** — Gherkin has a grammar |
| **Every relationship between the above** | **nobody today** | **owns outright** |

`INFERENCE` This is not a hedge; it is the actual gap. No system today owns
`AC → Scenario → step → test → run → commit → merge commit → release → incident`.
Atlassian sees the left, GitHub the middle, Grafana the right. Owning the edges is
additive to all three, never in conflict, and needs no write access to any system
of record. It also makes the sync model trivial: Specera never overwrites Jira.

## 2. Non-negotiable mechanics

Four, each answering a specific measured finding.

1. **Provenance on every edge** — `EXTRACTED` / `INFERRED` / `AMBIGUOUS`, as
   Graphify does (`graphify/validate.py:5`). An edge read from an AST and an edge
   guessed by a model must never be the same row.
2. **Confidence filtering at query time, high-confidence by default.** `FACT` No
   engine in this spike does this: codegraph discards confidence at write time;
   codegraphcontext and stakgraph store it and never read it — 0 hits for a
   threshold against 25 unfiltered `[:CALLS|HEURISTIC_CALLS]` traversals. Opting
   into low-confidence edges must be explicit and labelled in the answer.
3. **Artifacts keyed to the merge commit**, not the head SHA. `FACT` Head SHAs
   survive 19.83% of merges (25.0% in a mature corpus, median repo 0%); merge
   commits resolve at 99.5%.
4. **Bail out rather than guess.** `FACT` The measured failure mode is coverage,
   not precision — 72:28 EXTRACTED:INFERRED. Sparse-but-true is what keeps this
   out of the ~33%-precision category that
   [`comparison.md`](comparison.md) §3 shows reviewers already distrust.

## 3. Ontology

`FACT` Start from **potpie's SDLC ontology** — Apache-2.0, 24 entity types, 26
predicates, 15 agent-writable record types, with per-entity freshness TTLs,
source-of-truth classes and evidence strengths already modelled
(`potpie/context-core/src/potpie_context_core/ontology.py`). It is the closest
existing artifact to this target and it is legally reusable. Do not re-derive it.

`FACT` **Scope correction, 2026-08-04:** only `context-core` is safe. potpie's
*engine* depends on **FalkorDB, which is SSPL v1**. The reusable part is the
pydantic-only ontology package — specifically its per-type `freshness_ttl_hours`
and `source_of_truth` (`ontology.py:160-165`), `EVIDENCE_STRENGTHS` (`:92`), and
the `invalid_at` supersession rule (`:200-207`) that becomes our bitemporal edge.
`INFERENCE` Since the stack is TypeScript, this is a **port of a data model**, not
a runtime dependency — which also sidesteps the language boundary.

`INFERENCE` Extend it with the node types Graphify's own vocabulary lacks —
`Requirement`, `AcceptanceCriterion`, `Scenario`, `Step`, `Release`, `Incident` —
and with the `EXTRACTED`/`INFERRED`/`AMBIGUOUS` provenance enum on every edge.

Legally binding constraints from [`comparison.md`](comparison.md) §5: **GitNexus
is study-only** (PolyForm Noncommercial), **stakgraph is unusable** (no licence),
**sourcebot is reject** (FSL competing-use). Anything borrowed from bloop must
come from HEAD, never history.

## 4. Build order — moved and reordered

**Superseded by [`../roadmap.md`](../roadmap.md).** The ordering originally given
here has been replaced twice, and both changes are recorded rather than applied
silently:

`INFERENCE` **Platform-first, not slice-first.** This section read as though the
platform grew incrementally. That violates the architecture rule in §1 — adding a
connector must never change core. The platform is complete at M0; connectors plug
in afterwards. Anything touching the data model or the trust boundary (tenancy,
audit, provenance) is expensive to retrofit and cannot be sequenced late.

`INFERENCE` **Code first, not Gherkin first.** The table here opened with a
Gherkin spine on the grounds that it is the only intent artifact with a grammar.
That property is real and still holds — but `FACT` 0 of 19 clones contain any
`.feature` file. Connectors are now ordered by how reliably the source data
exists: code (100%) → git (99.5%) → tracker (48%) → test (66%) → Gherkin
(unmeasured) → runtime. Gherkin is a first-class connector, not the spine.

`INFERENCE` The second change generalises: every intent artifact this design
relies on — ADR, PRD, acceptance criteria, Gherkin — is absent from 100% of the
repositories measured, with one live Jira (n=3) as the only positive evidence.
That is carried as open questions Q1 and Q2 in the build roadmap and should be
answered before committing to the intent tier.

## 5. Surfaces

- **MCP server** — the primary interface, for coding agents and IDEs. Query
  surface must expose provenance so an agent can distinguish ground truth from
  guess, and must default to high-confidence.
- **CLI** — local-first, no account required to index a repo, following
  Graphify's zero-egress posture.
- **Read-only connectors** for Jira, GitHub and Grafana. `FACT` Jira's write path,
  if ever needed, is the **Builds API** (`/rest/builds/0.1/bulk`, carries typed
  `testInfo`) — not the Development Information API, which carries only branches,
  commits and PRs.

`INFERENCE` Connectors must be plugins behind a stable contract. If the core has
to change to add a connector, the architecture is wrong — that is how a
six-connector list becomes an unmaintainable surface.

## 6. Governance is the product

`INFERENCE` The graph is substrate. What people adopt is **policy over the
graph**: "no release with an acceptance criterion that has no scenario", "a PR
touching this service requires an ADR", "every incident traces to a release".
Nobody ships this because nobody has an end-to-end graph to run policy on.

Policy must be evaluated from the **base branch**, not the head — `security.md`
§8 established that a rule living in the PR under review can be deleted by the PR
that violates it. And per `security.md` §2.4, any merge-blocking check must be a
verifier the customer runs against their own trust root; a vendor-posted check
proves nothing.

## 7. Open questions carried into the build

- `UNVERIFIED` Do enterprise Jira estates carry structured, individually
  addressable acceptance criteria at a useful rate? One live Jira showed
  structured `## Acceptance Criteria` blocks; n=3 is an anecdote. This is the
  adoption condition in [`decision.md`](decision.md) §7.2 and the first thing to
  measure with a real customer.
- `UNVERIFIED` Whether `AC → Scenario` authoring is acceptable to teams as a
  human gate, or whether it is the annotation-burden problem in a new costume.
- ~~Storage is undecided.~~ **Settled 2026-08-04** in [`stack.md`](stack.md) §1–§3:
  relational, no graph database — `node:sqlite` in the CLI, Postgres on the
  server, recursive CTEs, with `edges_raw` as the base table and a
  confidence-filtered view named `edges`. `FACT` Every embedded graph database
  failed the liveness or licence gate (Kuzu archived, Cozo dormant, Cayley dead,
  SurrealDB/Memgraph BSL, FalkorDB SSPL, Neo4j GPL-3.0). `UNVERIFIED` The
  remaining risk is recursive-CTE performance at 10⁶+ edges, tracked as Q3 in
  [`../roadmap.md`](../roadmap.md).
