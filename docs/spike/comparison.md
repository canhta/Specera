# Comparison — differentiators and market gaps

Cross-cutting analysis only. Per-competitor detail lives in
[`competitors/`](competitors/index.md) and is not repeated here. Acquisition
metadata and licenses are in [`inventory.md`](inventory.md).

## 1. The category map

Twenty-nine products, four honest categories. Most "competitors" are components.

| Category | Members | Competes with Specera? |
|---|---|---|
| Lexical retrieval | [zoekt](competitors/zoekt.md), [opengrok](competitors/opengrok.md), [sourcebot](competitors/sourcebot.md) | No — foundation layer |
| Symbolic / graph | [GitNexus](competitors/gitnexus.md), [codegraph](competitors/codegraph.md), [codegraphcontext](competitors/codegraphcontext.md), [stakgraph](competitors/stakgraph.md), [graphify](competitors/graphify.md), [serena](competitors/serena.md) | Layer, not product |
| Context packing / comprehension | [repomix](competitors/repomix.md), [gitingest](competitors/gitingest.md), [code2prompt](competitors/code2prompt.md), [deepwiki-open](competitors/deepwiki-open.md), [gitdiagram](competitors/gitdiagram.md), [aider](competitors/aider.md) | No |
| SDLC platforms | [GitLab Duo](competitors/services/gitlab-duo.md), [GitHub Copilot](competitors/services/github-copilot.md), [Atlassian Rovo](competitors/services/atlassian-rovo.md), [Sourcegraph](competitors/services/sourcegraph.md) | **Yes — existentially** |
| PR-review products | [CodeRabbit](competitors/services/coderabbit.md), [Greptile](competitors/services/greptile.md), [Augment](competitors/services/augment-code.md), [Graphify Platform](competitors/services/graphify-platform.md) | Yes, on one node |

`INFERENCE` Only the fourth row threatens the thesis. Everything above it is a
build-or-integrate decision, not a market contest.

## 2. Four gaps that are real

Each is stated as a mechanism nobody has shipped, verified in source or docs, and
each is falsifiable. These are the only defensible openings found.

### Gap 1 — Confidence is computed, stored, and then ignored

`FACT` Three independent graph engines compute per-edge confidence and **none
filters on it at query time**:

- [codegraph](competitors/codegraph.md) discards it at write time — no confidence
  column on `edges` (`src/db/schema.sql:45-56`), so a 0.5 fuzzy name match and a
  0.95 import-resolved edge are byte-identical rows.
- [codegraphcontext](competitors/codegraphcontext.md) persists `confidence`,
  `resolution_tier`, and a separate `HEURISTIC_CALLS` relationship type, then
  never reads them. Coordinator-verified: `grep -rn "min_confidence\|
  confidence_threshold\|confidence >" src/` returns **0 hits**, against **25**
  occurrences of unfiltered `[:CALLS|HEURISTIC_CALLS]` traversal — including
  variable-depth `*1..{max_depth}` paths, and including tier-9 edges of
  confidence 0.08 that resolve to the caller's own file.
- [stakgraph](competitors/stakgraph.md) persists it and never reads it.

`INFERENCE` Persisting confidence is half the design. Defaulting every traversal
to the high-confidence subset — and making low-confidence opt-in and visibly
labelled — is the half nobody has shipped. This is cheap to build and directly
determines whether an impact claim is trustworthy.

### Gap 2 — Artifacts are not bound to a commit

`FACT` No generated artifact in this set carries the revision it describes.
[deepwiki-open](competitors/deepwiki-open.md) keys its wiki
`{type}_{owner}_{repo}_{lang}` with no SHA, clones `--depth=1` and never fetches
again, and reuses its FAISS index whenever present.
[gitdiagram](competitors/gitdiagram.md) omits the SHA from its cache key even
though the tree SHA is in a response it already fetches.

`INFERENCE` An artifact keyed by a commit is *automatically* invalid when the
commit moves — staleness becomes detectable rather than asserted, with no
heuristic. Nobody does this, and it is nearly free.

### Gap 3 — Nobody verifies edges, only that entities exist

`FACT` [gitdiagram](competitors/gitdiagram.md) validates every claimed file path
against the authoritative git tree with typed, counted, user-visible failure
categories — real grounding — but `getGithubData` fetches only the tree and
README, **never file contents** (`github.ts:406`), and edge validation checks
only that both endpoints are known node ids (`graph.ts:144-163`). Every arrow in
the diagram is model invention over a filename list.

`INFERENCE` The differentiator must therefore be stated as **"edges derived from
parsed code"**, not "we validate our output" — validation of *nodes* is already
shipped, and better than a hand-rolled version would be. See
[`security.md`](security.md) and [`red-team.md`](red-team.md) for whether this
survives contact.

### Gap 4 — Requirement linkage is a verdict or a string, never evidence

The convergent finding across all four incumbents, and the sharpest gap:

| Vendor | Requirement → code linkage | AI may block a merge? |
|---|---|---|
| [GitLab Duo](competitors/services/gitlab-duo.md) | `Requirement IID → "passed"/"failed"` — records *that* it passed, never which test, commit, or evidence proved it. `{"*":"passed"}` marks **every** open requirement satisfied in one line | **No** — "never sets the Approve state, even when it finds no issues" |
| [Atlassian Rovo](competitors/services/atlassian-rovo.md) | **Validates PR diffs against Jira acceptance criteria, three verdicts per criterion — GA, GitHub included** | No documented merge gate |
| [GitHub Copilot](competitors/services/github-copilot.md) | Closing keyword in a PR description; ≤10 manual links; default branch only | **No** — "does not count toward required approvals… will not block merging" |
| [CodeRabbit](competitors/services/coderabbit.md) | Issue Assessment reads Jira acceptance criteria | Overridable; blind to unlinked issues; unbenchmarked |
| [Greptile](competitors/services/greptile.md) | Jira read-only — "Greptile never writes to Jira" | No merge blocking found; ships **auto-approve** instead |

**The detection half of this gap is closed.** `FACT` Rovo Dev code review already
validates a PR diff against Jira acceptance criteria with a met / missing /
needs-manual-check verdict per criterion — GA, not beta, on GitHub as well as
Bitbucket, on by default in Bitbucket, at $20/dev/month. Any Specera pitch built
on "we check whether the PR satisfies the ticket" is already a shipped feature of
the Jira incumbent.

`INFERENCE` What remains undone is the **artifact**, and only the artifact: Rovo
emits prose in a comment with no per-criterion identifier, no merge gate, and —
verified first-hand below — a 90-day retention window. GitLab has the containers
for evidence and refuses to let AI fill them. GitHub has agents everywhere and
evidence nowhere. Specera's position must therefore be **evidence, not
detection**; if it is stated as detection it is dead on arrival.

**First-hand verification of the Teamwork Graph's limits** (read-only MCP against
a live Jira site, 2026-08-04): `FACT` `getTeamworkGraphContext` on three live work
items — including an Epic — returned **only `AtlassianUser` relationships**. No
PR, repo, build, deployment, or Confluence edges, and not even the epic→child
edge that `searchJiraIssuesUsingJql` confirms exists (`FUT-797.parent = FUT-792`).
`getJiraIssueRemoteIssueLinks` returned `[]`. Every traversal warned that results
"were truncated to the retention window of **90 days**."

`INFERENCE` A graph that forgets status-change history after a quarter cannot
serve an audit, which is precisely the use case that would justify Specera. Note
also that Teamwork Graph **is** a real typed graph (ARIs, named predicates,
Cypher via a GraphQL `cypherQuery`) — that question is settled — but its API is
Early Access and "may not be deployed to production or distributed", so no third
party can build on Atlassian's best asset today, Specera included.

## 3. The gap that is not real — precision

`FACT` An independent, MIT-licensed benchmark exists and contradicts vendor
claims: `withmartian/code-review-benchmark` (224 stars, pushed 2026-07-13,
results across three judge models). Greptile's own benchmark claims an 82% catch
rate while admitting "false positives… did not affect the catch rate."
Independently judged on the same corpus: **Greptile v4 ~57% recall / ~33%
precision; CodeRabbit 25.7% precision; Copilot 28.3%.** Detail and caveats:
[`competitors/services/greptile.md`](competitors/services/greptile.md).

`INFERENCE` This cuts **against** Specera, not for it. The category ships
findings at roughly one-in-three precision, and reviewers already distrust them —
CodeRabbit's own suppression heuristic hides a comment type after it is ignored
three times. Any Specera claim that it will "surface impact" inherits this
problem. Precision is not a gap waiting to be filled; it is the reason the
category is mistrusted, and a reason to prefer deterministic checks over model
findings wherever a deterministic check exists. This is the strongest argument in
the spike *against* an LLM-centred design.

## 4. Scope reality check

`FACT` [GitLab Duo](competitors/services/gitlab-duo.md) covers eight of ten SDLC
rows at least partially and four well — broader than GitHub. Native `Requirement`
objects, release evidence JSON with `report_artifacts`, in-toto/SLSA provenance,
merge-blocking policy-as-code, external status checks a third party can occupy,
and streamed audit events.

`INFERENCE` For a GitLab Ultimate shop, most of Specera's proposed scope is
already shipping. The only genuine holes are architecture/ADR — absent entirely
across every competitor — and the *quality* of requirement↔code evidence.
Proposing an eleven-stage platform against this is the single largest scope risk
in the spike, and [`red-team.md`](red-team.md) is instructed to attack it.

## 5. Licensing verdicts that constrain the build

`FACT`, from license files (see [`inventory.md`](inventory.md)):

| Verdict | Components |
|---|---|
| **Integrate** | zoekt (Apache-2.0) — lexical tier; serena `solidlsp` (MIT) — compiler-grade symbols; Jira's two write paths (below) — production-supported and third-party-writable, so evidence goes *into* Jira rather than a parallel link store |
| **Borrow** | potpie's SDLC ontology (Apache-2.0) — 24 entities, 26 predicates, bitemporality, evidence strength; aider's repo-map ranking and edit-format parsers (Apache-2.0); codegraphcontext's `HEURISTIC_CALLS` type-splitting (MIT); gitdiagram's schema-constrained generation (MIT) |
| **Study only** | GitNexus (PolyForm Noncommercial) — best-engineered graph in the set, 46 node labels with real C++ ADL and DI resolution, legally untouchable |
| **Reject** | sourcebot (FSL, competing-use clause); stakgraph (no LICENSE — all rights reserved); opengrok (CDDL entanglement) |

`INFERENCE` The best graph engineering in the category is unusable IP and the
best SDLC ontology is freely reusable — so Specera should reimplement the
resolver and adopt potpie's ontology, not the reverse.

**Jira has two distinct write paths, and the difference matters.** `FACT`
(both verified HTTP 200, 2026-08-04): the **Development Information API**
(`POST /rest/devinfo/0.10/bulk`, `devops:developmentInfoProvider`) carries
branches, commits, and pull requests and renders in the Jira development panel;
the **Builds API** (`/rest/builds/0.1/bulk`) is the one that carries a typed
`testInfo` object with `numberPassed` / `numberFailed`
(https://developer.atlassian.com/cloud/jira/software/rest/api-group-builds/).
`INFERENCE` Any design that writes *test outcomes* into Jira must target the
Builds API; devinfo is the wrong surface for that payload and would force test
results into prose or custom fields. Correction contributed by the blue team and
verified by the coordinator.

## 6. What this implies for the concepts

Carried into [`product-concepts.md`](product-concepts.md) as constraints, not
conclusions:

1. The defensible mechanism is **evidence quality**, not graph coverage — the
   graph category is six months old, unconsolidated, and commoditising.
2. Any concept must **prefer deterministic verification to model findings**, given
   §3. LLM-only judging is the weakest available evidence.
3. Any concept must **survive the scope argument in §4** or narrow until it does.
4. Architecture/ADR is the one stage **no competitor covers at all**.
