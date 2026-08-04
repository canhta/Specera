# Spike Plan — Specera

Status: **Complete — NO-GO** · 2026-08-04 · two rounds of three used

Outcome in [`decision.md`](decision.md). Round 1 returned pivot with no concept
above 4.1/10; round 2 tested the pivot's two decisive questions and found the
residue empty. Round 3 was not run because round 2 was determinate.

## Objective

Decide whether to build a differentiated platform covering the full SDLC
(business objective → PRD → Jira → architecture/ADR → implementation → GitHub PR →
Gherkin/testing → security/pentest → release → monitoring/incidents → maintenance),
for both greenfield and maintenance projects.

Output is a go / pivot / no-go decision backed by technical evidence, not a build.

## Method

```text
Research → Proposal → Blue team → Red team → Verification → Score → Refine | Pivot | Reject
```

Maximum three rounds. Each round must end with a written score in
[`evaluation.md`](evaluation.md) and a decision delta in [`decision.md`](decision.md).

Evidence preference order (highest first):

1. Executable tests run against cloned code
2. Static analysis / schema checks / security scanners
3. Source reading with commit hashes and file paths
4. Official vendor documentation
5. LLM-only judgement — **lowest**, must be labelled `INFERENCE`

## Claim labelling (mandatory in every document)

| Label | Meaning |
|---|---|
| `FACT` | Verified in cloned source, executed command, or primary doc. Must cite path/commit/URL. |
| `INFERENCE` | Reasoned conclusion from facts. Must state the facts it rests on. |
| `VENDOR CLAIM` | Asserted by the vendor, not independently verified. |
| `UNVERIFIED` | Believed but unchecked. Must say what would verify it. |

## Workspace

| Path | Contents |
|---|---|
| `.spike/clones/<repo-name>` | Full-history clones. Not committed. |
| `.spike/logs/` | Clone and analysis logs. Not committed. |
| `docs/spike/` | All canonical documentation. Committed. |

Rules: one file per competitor; one canonical file per topic; update in place;
never create `v2` / `new` / `final` / backup variants; link instead of repeating.

## Round 1 — agent assignment

### Wave 1: research (parallel, non-overlapping)

| Agent | Scope | Owns files |
|---|---|---|
| R1 | Code-graph engines: graphify, GitNexus, potpie, codegraph, codegraphcontext, stakgraph | `competitors/{graphify,gitnexus,potpie,codegraph,codegraphcontext,stakgraph}.md` |
| R2 | Search & semantic retrieval: serena, grepai, claude-context, sourcebot, zoekt, opengrok, bloop | `competitors/{serena,grepai,claude-context,sourcebot,zoekt,opengrok,bloop}.md` |
| R3 | Context packing & agents: repomix, aider, gitingest, code2prompt, deepwiki-open, gitdiagram | `competitors/{repomix,aider,gitingest,code2prompt,deepwiki-open,gitdiagram}.md` |
| R4 | Commercial A: Graphify Platform, GitNexus Enterprise, Sourcegraph, Augment Code, Greptile | `competitors/services/{graphify-platform,gitnexus-enterprise,sourcegraph,augment-code,greptile}.md` |
| R5 | Commercial B: CodeRabbit, DeepWiki/Devin, GitHub Copilot, GitLab Duo, Atlassian Rovo | `competitors/services/{coderabbit,deepwiki-devin,github-copilot,gitlab-duo,atlassian-rovo}.md` |

No agent may write outside its assigned files. Cross-cutting synthesis happens
only in `comparison.md`, written by the coordinator.

### Wave 2: design and adversarial review (sequential dependencies)

| Agent | Input | Owns |
|---|---|---|
| A1 Product/SDLC architecture | competitor files, `comparison.md` | `sdlc-model.md`, `product-concepts.md` |
| A2 Blue team | `product-concepts.md` | `blue-team.md` |
| A3 Red team (independent) | `product-concepts.md`, `blue-team.md` **conclusions only** | `red-team.md` |
| A4 Security red team | concepts + architecture | `security.md` |
| A5 Evaluation | all of the above | `evaluation.md` |

The red team receives proposal artifacts only — never the blue team's private
reasoning, working notes, or rebuttals prepared in advance.

Coordinator writes `comparison.md`, `product-proposal.md`, `roadmap.md`,
`decision.md`, `inventory.md`.

## Product concepts (round 1)

Three concepts, evaluated against each other. **Continuous Change Assurance is a
candidate, not a foregone conclusion** — the evaluation must be able to reject it.

See [`product-concepts.md`](product-concepts.md).

## Red-team mandatory challenge list

Differentiation and customer value · excessive scope · graph accuracy and
freshness · dynamic and cross-repository dependencies · database migrations and
rollback · missing tests and false positives · prompt injection and excessive
permissions · forged evidence and data leakage · performance, cost, adoption,
licensing.

## Kill criteria for the spike itself

Stop and write a no-go if any holds after round 3:

- **No compounding advantage.** See the ruling below.
- Graph/evidence accuracy cannot be demonstrated above a useful threshold on real repos.
- The only viable wedge requires permissions no security team would grant.
- The product's core claim cannot be made truthfully (see
  [`security.md`](security.md) on unprovable test–criterion correspondence).

### Ruling — amended 2026-08-04, coordinator

The first criterion originally read: *"no differentiator survives red team that a
competitor cannot ship in one quarter."* The blue team escalated that this test,
applied strictly, kills Concepts 1 and 3 and leaves only Concept 2 — whose buyer
has no budget — and therefore decides the spike by definition rather than by
evidence.

**The objection is correct and the criterion was badly specified.** Nearly every
software differentiator is technically copyable in a quarter; a test that
everything fails is not a test. It is replaced, deliberately in the direction of
*more* rigour rather than less:

> **A concept is killed if it has no compounding advantage** — nothing that gets
> harder to displace the longer the product runs. Technical copyability alone is
> not a kill. Absence of accumulating state, switching cost, proprietary data, or
> a structural incentive the incumbent lacks **is** a kill.

Three consequences, binding on [`evaluation.md`](evaluation.md):

1. "An incumbent could build this" is **not** sufficient to reject a concept. The
   evaluation must say why they *would*, and what they would have to give up.
   `FACT` Rovo shipped the *detection* half of requirement-checking and not the
   *evidence* half; that asymmetry is evidence about incentives, not oversight,
   and must be explained rather than assumed away.
2. A concept whose only defence is a head start **is** killed. Time-to-market is
   not a moat.
3. Accumulated evidence with retention guarantees is a candidate compounding
   advantage — an evidence ledger is worth more in year three than year one, and
   `FACT` Rovo's Teamwork Graph discards history after 90 days. Whether that
   asymmetry is durable or merely a current product gap is a **question for the
   red team**, not an assumption the blue team may bank.

This ruling is recorded rather than applied silently because it changes the
outcome, and a reader must be able to disagree with it.

## Document index

[`inventory.md`](inventory.md) ·
[`competitors/index.md`](competitors/index.md) ·
[`comparison.md`](comparison.md) ·
[`sdlc-model.md`](sdlc-model.md) ·
[`product-concepts.md`](product-concepts.md) ·
[`blue-team.md`](blue-team.md) ·
[`red-team.md`](red-team.md) ·
[`security.md`](security.md) ·
[`evaluation.md`](evaluation.md) ·
[`product-proposal.md`](product-proposal.md) ·
[`roadmap.md`](roadmap.md) ·
[`decision.md`](decision.md)
