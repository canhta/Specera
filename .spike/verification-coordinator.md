# Coordinator verification of contested round-1 numbers

2026-08-04. Independent re-measurement by the coordinator where blue and red
disagreed, or where a number is load-bearing for the decision. Raw notes; the
conclusions land in [`decision.md`](../docs/spike/decision.md).

## 1. Test-touch rate — red team corroborated, blue team's figure was optimistic

Coordinator method: for each clone, the 400 most recent non-merge commits;
count commits touching a source extension, and of those, the share also touching
a path matching `tests?|spec|__tests__|testdata|e2e` or `_test|.test|.spec|Test.`.

Result: **median 32%**, **10 of 19 repos below 35%**.

| Source | Median | Repos < 35% | Sample |
|---|---|---|---|
| Blue team | 45% | — | 9 repos |
| Red team | 34% | 10/19 | 19 repos |
| **Coordinator** | **32%** | **10/19** | 19 repos |

`FACT` The red team's measurement replicates; the blue team's does not. The 11-point
gap is sampling — the blue team's 9 repos included graphify (88%), codegraph (89%),
and GitNexus (95%), which are the three highest in the corpus. Per
[`plan.md`](../docs/spike/plan.md)'s evidence ordering, the 19-repo figure with a
stated command wins.

`INFERENCE` The blue team set its own threshold at ≥35% of merged PRs touching a
test and then failed it on the full corpus. That is disqualifying for the
substrate claim as written, and it happened without any adversarial pressure —
the blue team simply sampled the repos it had already been reading.

Per-repo: GitNexus 95, codegraph 89, graphify 88, grepai 66, repomix 54, zoekt 50,
opengrok 43, serena 42, codegraphcontext 39, gitdiagram 32, potpie 31, stakgraph 27,
gitingest 26, sourcebot 22, code2prompt 12, claude-context 10, aider 6,
deepwiki-open 3, bloop 0.

## 2. SHA rewriting at merge — measurements disagree; red team's method is better

`UNVERIFIED` The red team reports **13/19** repos rewrite SHAs at merge (9
squash-dominant, 4 rebase-heavy), stating it demonstrated in git that an attested
head SHA is not an ancestor of mainline and is garbage-collected.

The coordinator's re-measurement used a **weaker proxy** — merge-commit ratio over
the last 300 commits, classifying <10% merges as linear — and produced **6/19**.

**Do not treat 6/19 as a refutation.** The proxy is invalid for the question:
a repository can carry merge commits from release branches while still
squash-merging every pull request, and merge-commit ratio cannot distinguish
those. The red team tested ancestry, which is the correct test. The coordinator
did not reproduce the ancestry test.

`INFERENCE` The direction holds under either number and is what matters for the
design: squash-merge is a common default on GitHub, it destroys the head SHA an
evidence artifact would be keyed by, and the design has no answer for it. Whether
the true rate is 30% or 70% of repositories changes the size of the problem, not
its existence. **Round 2 must reproduce the ancestry test properly** —
`git merge-base --is-ancestor <pr-head-sha> origin/main` over a sample of merged
PRs obtained from the GitHub API — before any number is published as `FACT`.

## 3. Xray already occupies the wedge — verified, red team correct

`FACT` `Xray-App/xray-junit-extensions` (GitHub API, 2026-08-04): licence
**EPL-2.0**, last push **2026-04-15**, not archived. Its README documents
`@Requirement("CALC-1234")`, `@Requirement({"CALC-1234", ...})`, `@Requirements`,
and `@XrayTest`. The Atlassian Marketplace lists "Xray - Test Management for Jira"
(vendor Xblend).

`INFERENCE` This is the single most decision-relevant fact in round 1. The blue
team nominated its budget claim — that Xray/Zephyr customers pay for manually
asserted requirement↔test links *with no execution proof* — as "the single most
important unchecked fact in the proposal," and it is false in the direction that
hurts: Xray supplies the annotation, the CI import, and coverage computed from
executed runs. The residue Specera would sell is narrower than the proposal
assumes.

## 4. Method note

Commands for §1 and §2 are in the shell history of this session and are
reproducible against `.spike/clones` at the HEADs recorded in
[`inventory.md`](../docs/spike/inventory.md). §1 is a single awk pipeline over
`git log --name-only`; §2's proxy is deliberately not carried forward.
