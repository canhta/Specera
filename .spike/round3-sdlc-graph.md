# Round 3 — "Graphify, but for the whole SDLC": can the non-code edges be extracted?

Scope: the re-specified target only; rounds 1–2's no-go is not re-litigated. Corpus: the 19 clones in `.spike/clones/`, `gh` GraphQL
against their upstreams, one live Jira site. Measured 2026-08-04. Scripts in `scratchpad/`: `m1.py` (commit refs),
`m2_fetch.sh`+`m2.py` (PR→issue/tag), `m3b.py` (test→code), `m5.py` (doc→code), `m6.sh` (issues).

**Samples.** 39,703 no-merge commits (`git log --no-merges --pretty=format:'%s%n%b'`) · 4,491 merged PRs (`gh api graphql`,
`pullRequests(states:MERGED,first:100)`×3 pages, fields `number title bodyText headRefName mergeCommit{oid}
closingIssuesReferences{totalCount}`) · 3,252 issues (`issues(first:100)`×2, fields `parent subIssues trackedIssues trackedInIssues
timelineItems(CROSS_REFERENCED,CONNECTED)`) · 1,917 markdown docs · 4,596 test files · 100 live Jira issues (project FUT, Rovo MCP
`searchJiraIssuesUsingJql`, fields `parent issuelinks issuetype`).

## 1. Commit / PR → work item — PARTIAL, coverage-limited

`FACT` Over 39,703 commits: `(#N)` ending the subject **16.1%** pooled / 29.0% median; any `#N` **21.1%** pooled / **48.1% median**
(range 1.4% aider – 95.1% bloop); Jira-style `ABC-123` **0.8%**; closing keyword 3.8%. Tokens that are present **resolve**: of 2,939
in-window `(#N)` subject refs checked against the fetched merged-PR set, **92.0%** are a merged PR, and the outlier (graphify,
22.6%) is not dangling — 15/15 sampled non-PR numbers resolve via `gh api repos/Graphify-Labs/graphify/issues/N` to a real object
(13 issues, 2 PRs). GitHub's shared number namespace makes issue-vs-PR one API call, not a guess.

`FACT` PR → issue over 4,491 merged PRs: **17.1%** carry a GitHub-resolved `closingIssuesReferences` (median repo 12.8%); 18.2%
mention `#N` with no closing link (resolvable, but the *relation* is unstated); **64.7% carry no reference at all**. Branch names
carry a parseable key in 16.5%.

`INFERENCE` Deterministic when present; the variable is coverage, not accuracy. The 0.8% Jira rate is a corpus artifact
(GitHub-native OSS); the transferable finding is the **shape** — reference discipline is bimodal and per-team, spanning 1.4%–95.1%.

## 2. PR → release — DETERMINISTIC, and it repairs round 2's finding

`FACT` **99.5%** of 4,491 merged PRs have a `mergeCommit.oid` resolvable in the local clone (`git cat-file -e <oid>^{commit}`).
Round 2's 19.83% survival was measured on the **head** SHA, which squash discards; the **merge** commit is what GitHub writes to the
base branch and survives by construction. Of those, **82.8%** pooled are contained by ≥1 tag (`git tag --contains <oid>`); excluding
the 3 repos with zero tags (deepwiki-open, gitdiagram, zoekt), **92.9%** over 4,006 PRs, **median repo 93.3%** — the residual is
mostly "merged after the last tag." Release → commit-set is total: `git rev-list --count <tagN-1>..<tagN>` gave a clean count for
every pair tested (graphify v0.9.31..v0.9.32 = 14; repomix v1.16.1..v1.17.0 = 98; opengrok 1.14.14..1.14.15 = 6; sourcebot
v5.1.4..v5.1.5 = 7).

`INFERENCE` The only SDLC edges both deterministic *and* near-fully covered — computed from the DAG, not from a human convention.

## 3. Test → code — PARTIAL, precise, wrong granularity

`FACT` **0 of 19** repos commit coverage data (`lcov.info`, `coverage.xml`, `.coverage`, `coverage-final.json`, cobertura); **8 of
19** configure coverage tooling — the data is *producible by running the suite*, never by parsing a repo. Derived instead from
first-party imports (AST, per-language): **65.9%** of 4,596 test files link to ≥1 first-party module, **median repo 80.0%**, **mean
fan-out 1.7**. `INFERENCE` A good deterministic edge — precise and free. But it is `test-file → module`, not `test-case →
behaviour`, and not `test → requirement` (§6).

## 4. ADR → code — INFERRED-ONLY; the left-hand node does not exist

`FACT` Round 1 confirmed independently. `find <r> -not -path '*/.git/*' \( -ipath '*adr*' -o -ipath '*decision*record*' -o -ipath
'*/rfc/*' -o -ipath '*architecture-decision*' \)` returns one hit corpus-wide: `repomix/src/mcp/tools/readRepomixOutputTool.ts`, a
substring false positive ("re**adR**epomix"). **0 of 19 real ADRs.**

`INFERENCE` Not "hard to parse" — there is nothing to parse. Shipping this edge means making the customer author ADRs first: a
behaviour-change sale, not extraction. `sdlc-model.md` §2's "one uncontested stage" now reads as *unserved because unpopulated*, not
as an opening.

## 5. Doc → code — PARTIAL at path level, INFERRED-ONLY at symbol level

`FACT` **File paths** (10,761 path-like tokens across 1,917 docs vs `git ls-files`): **49.3%** resolve to a tracked file; **50.4%**
of docs contain ≥1 resolvable path; **24.6%** contain zero path tokens — pure prose. **Symbols** (19,817 distinct backticked
identifiers ≥4 chars vs `def/class/function/fn/func` definitions): **10.5%** resolve to exactly one definition · **4.8%** to more
than one (AMBIGUOUS — graphify's god-node case) · **84.7%** to none (CLI flags, env vars, config keys, prose).

`INFERENCE` Verifiable without a model — gitdiagram's mechanism (`comparison.md` §2 Gap 3). But yield is ~1 token in 10 at symbol
level, and a resolved path proves *mention*, never *describes* or *constrains*. The semantic half is not recoverable from the text.

## 6. Requirement → test, and the whole intent tier — zero data

`FACT` **0 of 19** repos contain any requirement-id annotation (`@Requirement`, `@Issue(`, `@TestCase(`,
`pytest.mark.issue|requirement|story`, `@allure.*`, `@Xray`, `@TmsLink`) — the three initial grep hits verified as false positives.
**0 of 19** contain a `.feature` file. Only 4/19 hold a PRD/requirements/spec-named doc; none carries addressable criteria. **0 of
19** contain an incident or postmortem record — the two `*incident*` files in potpie are benchmark scenario YAML
(`benchmarks/use_cases/COMBO/scenarios/combo_incident_to_prevention.yaml`).

`INFERENCE` These four edges have **zero extractable instances** — not low precision, no data. Incidents live in PagerDuty/JSM;
"which release caused this" is a human diagnosis.

## 7. Issue → issue — DETERMINISTIC mechanism, tracker-dependent population

`FACT` GitHub (3,252 issues): `parent` 0.9%, `subIssues` 0.2%, task-list tracking 0.4% — **1.5% with any hierarchy, 15 of 19 repos
at exactly zero**. Cross-reference timeline events are far richer: **median 53.3%** carry a
`CROSS_REFERENCED_EVENT`/`CONNECTED_EVENT`. Live Jira (FUT, 100 newest): **89 of 100 carry a `parent`** (e.g. `FUT-858 → FUT-304
(Epic)`, `FUT-857 → FUT-289 (Epic)`); types Bug 44 / Subtask 26 / Story 23 / Epic 6 / Task 1. Only **3 of 100** carry `issuelinks`
(2 `Blocks`, 1 `Relates`). `INFERENCE` A typed REST field, fully deterministic; population is set by the tracker. The one non-code
edge both deterministic and well-populated — and the one Jira renders natively, free.

## 8. Per-edge classification

| Edge | Class | Measured coverage |
|---|---|---|
| code → code (calls/imports/defines) | **DETERMINISTIC** | ~107k structural edges (50,196 defs + 57,020 imports, 10,710 files) |
| PR → merge commit | **DETERMINISTIC** | 99.5% of 4,491 PRs |
| release → commit set | **DETERMINISTIC** | 100% where tags exist (16/19 repos) |
| PR → release | **DETERMINISTIC** | 92.9% pooled / 93.3% median (tagged repos) |
| issue → parent/epic | **DETERMINISTIC** | Jira **89%**; GitHub 1.5% |
| issue ↔ issue (cross-ref) | **DETERMINISTIC** | median 53.3% (GitHub timeline) |
| issue → issue (blocks/relates) | **DETERMINISTIC** | 3% (Jira `issuelinks`) |
| test → module under test | **PARTIAL** | 65.9% pooled / 80.0% median, fan-out 1.7; coverage data 0/19 |
| commit → work item | **PARTIAL** | 21.1% pooled / **48.1% median**; 92%+ of tokens resolve |
| PR → issue | **PARTIAL** | 17.1% resolved + 18.2% prose-only; 64.7% none |
| doc → code (file path) | **PARTIAL** | 49.3% of tokens; 50.4% of docs ≥1 |
| doc → code (symbol) | **INFERRED-ONLY** | 10.5% unique / 4.8% ambiguous / **84.7% no definition** |
| ADR → code | **INFERRED-ONLY** | **0/19 — no left-hand node exists** |
| requirement → code | **INFERRED-ONLY** | 0/19 addressable criteria |
| requirement → test | **INFERRED-ONLY** | **0/19 annotations, 0/19 Gherkin** |
| incident → release | **INFERRED-ONLY** | **0/19 incident records** |
| PRD → work item | **INFERRED-ONLY** | 4/19 have a PRD-ish doc, none with ids |

## 9. The EXTRACTED : INFERRED ratio

**EXTRACTED, non-code — 30,003:** commit→work-item 8,459 · PR→merge-commit 4,469 · PR→release-tag 3,722 · PR→closing-issue 770 ·
test-file→module ~5,148 · doc→file 5,305 · doc→symbol 2,081 · issue→parent 49. (Excludes release→commit membership, ~39.7k, which
would inflate it.) **INFERENCE-DEMAND — ~52,496:** 31,244 commits with no work-item ref · 2,904 PRs with no issue ref · 16,782 doc
symbol tokens with no definition · 1,566 test files with no first-party import · plus every requirement/ADR/incident edge, whose
denominator is zero.

| Slice | EXTRACTED : INFERRED |
|---|---|
| Whole graph incl. code→code (107,216 structural) | **≈ 72 : 28** |
| **Non-code half only** | **≈ 36 : 64** |
| Intent tier (requirement, ADR, incident, PRD) | **0 : 100** |

`INFERENCE` 36:64 is close to `comparison.md` §3's ~33% precision figure, but the failure mode is different and materially better:
this is **coverage**, not accuracy. A missing edge is honest; a wrong edge is not. Applying graphify's own bail-out
(`extract.py:2405`, `if len(class_nids) != 1: continue`) to SDLC edges yields a graph that is **sparse but true**, not dense but
wrong — the opposite of the ~33% trap the target was feared to inherit. The decisive fact is not the ratio, though: the
deterministic non-code edges and the *valuable* non-code edges are **disjoint sets**. Everything extractable is git/tracker plumbing
— commit↔PR↔issue↔tag↔parent — which GitHub and Jira already render natively. Everything crossing from artifact to intent scores
zero.

## 10. Is the target occupied?

`FACT` **Graphify does not ship an SDLC graph.** In `.spike/clones/graphify`: `grep -rIl --include='*.py' -iE 'jira|atlassian'
graphify/` returns **0 files**; `graphify/prs.py` (761 lines) contains **no `add_node(`/`add_edge(` call** — it shells out to `gh`
and prints a dashboard, so PRs never enter the graph; `VALID_FILE_TYPES` (`graphify/validate.py:4`) is still the 6-value `{code,
document, paper, image, rationale, concept}` with no PR, issue, release, or incident node type; and there is no tag/release
awareness in the builder. `VENDOR CLAIM` The Jira connector is a YC-profile line with **no docs page**, from a 2-person company —
`competitors/services/graphify-platform.md` §2, §4.

`FACT` Rovo's Teamwork Graph *is* a real typed graph and the closest shipped thing — but `comparison.md` §2 records first-hand that
`getTeamworkGraphContext` on three live work items returned only `AtlassianUser` relationships (no PR/repo/build/deploy/Confluence
edges, not even epic→child), `getJiraIssueRemoteIssueLinks` returned `[]`, every traversal warned of a **90-day retention window**,
and the API is EAP, "may not be deployed to production or distributed." `FACT` Potpie has the best ontology (24 entities / 26
predicates, Apache-2.0) but its graph is LLM-reconciler-written with `DEFAULT_EVIDENCE_STRENGTH = "inferred"` —
`competitors/potpie.md` §2, §4.

`INFERENCE` **The gap is real and unoccupied** — nobody ships a deterministic SDLC graph. That is the good news; §9 is the bad news,
and they are one finding seen from two sides: the target is unoccupied partly because its extractable part is a thin restatement of
data GitHub and Jira already expose.

## 11. Verdict

**A deterministic SDLC graph is buildable, but it is a git/tracker-metadata graph, not an SDLC-understanding graph.**

The mechanism transfers cleanly: `PR→release` 92.9%, `release→commit` 100%, `issue→parent` 89% on Jira, `test-file→module` 65.9% at
fan-out 1.7, `commit→work item` 48.1% median with 92%+ token resolution — all real, zero-token, verifiable. Graphify's provenance
enum plus bail-out-on-ambiguity makes the sparse result honest rather than misleading. That is a defensible engineering artifact,
and it is not what the ~33% precision literature describes.

But the non-code half splits **36 : 64 EXTRACTED : INFERRED**, and the intent tier — requirement→code, requirement→test, ADR→code,
incident→release — is **0 : 100** with **zero source artifacts across all 19 repositories**. The deterministic non-code edges are
exactly the ones GitHub's PR sidebar and Jira's issue hierarchy already display; the edges that would justify a new product have no
left-hand node to extract from.

`INFERENCE` So this is **not** "just another LLM guessing over tickets" — the honest answer is worse in a quieter way: a truthful
graph of the plumbing, marketed as a graph of the lifecycle. Building it means either (a) shipping the plumbing graph and competing
on presentation against two incumbents who own the data, or (b) selling customers on authoring ADRs, addressable acceptance
criteria, and requirement annotations first — a behaviour-change sale in which the graph is the second product.

`INFERENCE` If anything carries forward, it is the narrowest slice where the measurement is strongest and the incumbents weakest:
**`PR → release → deployed artifact`**, 92.9% deterministic, computed from the DAG rather than from a convention. That is the same
mechanism `decision.md` §5 converged on independently (artifact-digest-bound evidence, immune to squash and rebase). Two rounds now
point at the same small thing.
