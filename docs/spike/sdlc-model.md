# SDLC model — stages, owners, evidence, gates

Design document. Constraints come from [`comparison.md`](comparison.md); competitor
detail is not repeated here, only linked. Two systems of record are **fixed and
non-negotiable**: Jira owns work and requirements, GitHub owns code, PR and
release. Anything Specera produces must land inside one of them or be addressable
from one of them; a parallel pane is not a system of record.

## 1. The chain

`INFERENCE` (design). "Evidence artifact" is the thing that must survive after the
conversation ends. "Gate" is what closes the stage: `Human`, `Auto`
(deterministic), or both.

| # | Stage | Human owner | System of record | Evidence artifact | Gate |
|---|---|---|---|---|---|
| 1 | Business objective | Product sponsor / exec | Jira (Initiative/Epic) | Objective with a measurable outcome and a target release | Human |
| 2 | PRD / requirements | Product manager | Jira work item + Confluence | **Individually addressable acceptance criteria** (`KEY.AC-n`), each phrased as a testable assertion | Human sign-off; `Auto` schema check that every AC has an id and a verifiable form |
| 3 | Work breakdown | Tech lead | Jira | Story/task carrying AC references and a parent link | Human (sprint commit) |
| 4 | Architecture / ADR | Architect / staff engineer | **GitHub** (`docs/adr/*.md`, versioned with the code it constrains) | ADR with context, decision, consequences, and a machine-checkable constraint block | Human (arch review); `Auto` conformance check of constraints against the graph |
| 5 | Implementation | Engineer (or agent under a named engineer) | GitHub (branch, commits) | Commits carrying the work-item key and agent attribution | `Auto` (build, lint, type check) |
| 6 | PR review | Reviewer | GitHub PR | Per-AC verdict, impact set, coverage delta — as a **machine-readable check conclusion**, not a comment | Human approval + `Auto` required status checks |
| 7 | Testing / Gherkin | QA engineer | GitHub (feature files, tests) + Jira (test plan) | **Executed** test result bound to `KEY.AC-n` and a commit SHA | `Auto` (run must pass) |
| 8 | Security / pentest | AppSec | GitHub code scanning + Jira (findings) | Scanner results and pentest report keyed to the release-candidate SHA | `Auto` (policy) for scanners; Human for pentest sign-off |
| 9 | Release | Release manager | GitHub (tag/release) | **Release evidence bundle**: commits, work items, AC verdicts, test runs, scan results, provenance attestation | Human release gate over an automatically assembled bundle |
| 10 | Monitoring / incidents | SRE / on-call | Incident tool (JSM, PagerDuty) | Incident record linked to the deployed release SHA and the observed impact set | `Auto` detection; Human post-incident review |
| 11 | Maintenance / learning | Owning team | Jira + repo | Fix records, bug patterns, **superseded** ADRs, failed-attempt records | Human |

Two rules that make the table a design rather than a diagram:

`INFERENCE` **Every evidence artifact is keyed by `(work item key, commit SHA)`.**
Basis: [`.spike/findings-artifact-grounding.md`](../../.spike/findings-artifact-grounding.md)
— no artifact in the competitor set carries the revision it describes, so
staleness is asserted rather than detected. A SHA-keyed artifact is automatically
invalid when the SHA moves.

`INFERENCE` **Every gate output is a status object with a stable identifier, not
prose.** Basis: [`comparison.md`](comparison.md) §2 Gap 4 — every incumbent AI
reviewer is constitutionally advisory ([GitLab Duo](competitors/services/gitlab-duo.md)
never sets Approve; [Copilot](competitors/services/github-copilot.md) "will not
block merging"; [Rovo](competitors/services/atlassian-rovo.md)'s AC verdicts are
comment prose). Prose leaves no record and closes no stage.

## 2. Who already owns each stage

`FACT` rows below are established in the linked competitor files and summarised in
[`comparison.md`](comparison.md) §4.

| # | Stage | Already served by | What is actually missing |
|---|---|---|---|
| 1 | Objective | Jira, Confluence natively | Nothing. **Do not build.** |
| 2 | PRD / requirements | [Rovo](competitors/services/atlassian-rovo.md) owns the artifact; [GitLab](competitors/services/gitlab-duo.md) has a `Requirement` object | AC is markdown prose in a description field — no per-criterion id to attach evidence to |
| 3 | Jira / work tracking | Atlassian, GitLab natively | Nothing. **Do not build.** |
| 4 | **Architecture / ADR** | **Nobody** — the only stage with zero coverage across all 29 products | Everything. ADRs are prose in Confluence, unlinked to code, never checked |
| 5 | Implementation | [Copilot](competitors/services/github-copilot.md), GitLab Duo, Rovo Dev, [aider](competitors/aider.md), Cursor | Nothing defensible. **Do not build.** |
| 6 | PR review | Rovo (AC-aware, GA, GitHub, $20/dev/mo), [CodeRabbit](competitors/services/coderabbit.md), [Greptile](competitors/services/greptile.md), Copilot | Detection is closed. What is open: a machine-readable, retained, merge-gating **record** — the required-check slot GitHub's own reviewer declines to occupy |
| 7 | Testing | Duo test generation; Greptile TREX runs tests in a sandbox | No binding from an executed test to a specific acceptance criterion. Rovo grades the *diff*, so an AC can read "met" with no test proving it |
| 8 | Security | GitLab (strongest row in the spike), GitHub CodeQL + Autofix | Nothing on scanning. **Do not build scanners.** Missing: findings bound into the release record |
| 9 | Release | GitLab release evidence JSON + in-toto/SLSA; GitHub owns Releases but nothing reasons about them | On GitHub: no release evidence artifact of any kind exists |
| 10 | Monitoring / incidents | Rovo/JSM and Compass own incidents natively | Nobody compares the impact a change was *predicted* to have with the impact it *had* |
| 11 | Maintenance / learning | Rovo Search (best in spike); [potpie](competitors/potpie.md)'s ontology models it | Decision supersession and failed-fix history tied to code, surviving beyond a retention window |

`INFERENCE` Five of eleven stages are closed to Specera outright (1, 3, 5, 8, and
the detection half of 6). One is wholly open (4). The remaining five are open only
at the **artifact and gate layer**, not at the detection layer. Any concept that
pitches detection on stages 2, 6 or 7 is competing with a GA feature of the Jira
incumbent at $20/dev/month.

`INFERENCE` The seams to build on, not beside, are all documented and third-party
usable: GitHub **Checks API** as a required status check
([github-copilot.md](competitors/services/github-copilot.md) §3), GitLab
**external status checks** with HMAC callbacks
([gitlab-duo.md](competitors/services/gitlab-duo.md) §3), and Jira's
**Development Information API** (`POST /rest/devinfo/0.10/bulk`,
`devops:developmentInfoProvider`) as the durable, production-supported write path
into Jira ([atlassian-rovo.md](competitors/services/atlassian-rovo.md) §2). The
Teamwork Graph API is EAP and may not be shipped on, by anyone.

`FACT` **Correction (coordinator, 2026-08-04):** devinfo carries branches,
commits, and PRs — **not** test outcomes. The typed `testInfo` object with
`numberPassed` / `numberFailed` belongs to the separate **Builds API**
(`/rest/builds/0.1/bulk`), verified at
https://developer.atlassian.com/cloud/jira/software/rest/api-group-builds/.
Stage 7's evidence artifact must therefore target the Builds API; writing test
results through devinfo would degrade them to prose or custom fields. See
[`comparison.md`](comparison.md) §5.

## 3. Greenfield and maintenance are different lifecycles

`INFERENCE` (design). Treating them as one lifecycle is a known failure mode: an
impact-analysis-first product is useless on day one of a greenfield project, and a
conformance-first product has nothing to conform to in a legacy repo with no ADRs.

| | Greenfield | Maintenance |
|---|---|---|
| Direction of evidence | Forward: decision → code. The artifact precedes the code it describes | Backward: code → which requirement or decision does this serve |
| Dominant risk | **Drift** — the code stops matching the decision that authorised it | **Blast radius** — nobody knows what a change breaks |
| Where the gates concentrate | Stages 2 and 4 (requirements, architecture) | Stages 6 and 9 (PR, release) |
| Cold start | No graph, no history, nothing to mine. The ADR *is* the seed data | A graph and years of history exist and are the primary asset |
| Impact analysis | Meaningless — there is nothing to impact | The core value |
| Conformance checking | The core value | Requires reconstructing decisions that were never written down |
| Requirements | Authored, structured, current | Often reconstructed from code and tickets, frequently absent |

`INFERENCE` A single product must therefore either (a) pick one mode and say so,
or (b) ship two distinct entry rituals — a greenfield ritual that starts from an
authored ADR and PRD, and a maintenance ritual that starts from a repo scan and a
backfill of decisions from existing code. Option (b) is two onboarding products
and roughly two roadmaps; it should not be assumed free.

`INFERENCE` The maintenance mode is the larger market and the harder technical
problem (it depends entirely on graph accuracy, which
[`comparison.md`](comparison.md) §1 shows is commoditising and §3 shows is
mistrusted). The greenfield mode is the smaller market and the easier problem, and
it is the mode in which stage 4 — the one uncontested stage — is most valuable.
This tension is carried into [`product-concepts.md`](product-concepts.md) and is
not resolved here.
