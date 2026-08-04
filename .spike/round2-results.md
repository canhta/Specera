# Round 2 verification — Test A (Xray residue) and Test B (ancestry)

Agent R2-V, 2026-08-04. Owner of this file only. Thresholds pre-committed in
[`evaluation.md`](../docs/spike/evaluation.md) §7 (R2-5, R2-1). Labels per `plan.md`.
All URLs fetched 2026-08-04. `docs.getxray.app` 403s automated fetches; the same pages are
public on `getxraydocs.atlassian.net` (Xray's own Confluence) and were read there.

## Test A — is anything left after Xray?

**A1 · Is `Revision` SCM-validated? — NO. Free text.**
`FACT` Xray Cloud's JSON import `info` object has exactly ten fields: `project`, `summary`,
`description`, `version`, **`revision`**, `user`, `startDate`, `finishDate`, `testPlanKey`,
`testEnvironments`. `revision` is documented as **"A revision for the revision custom
field."** No SCM validation, no repo reference, no commit-existence check anywhere.
<https://getxraydocs.atlassian.net/wiki/spaces/XRAYCLOUD/pages/44565311>
`FACT` `mikepenz/xray-action` documents its `revision` input as *"Source code and
documentation version used in the test execution"* — a string the CI caller asserts
(<https://github.com/mikepenz/xray-action/blob/main/README.md>). It is a Jira custom field
(`customfield_NNNNN`), editable by anyone with Edit Work Items permission.
**Threshold R2-5(a) "validated → reject": does not fire.** But Specera would only *verify a
string Xray already accepts unverified* — a correctness fix, not a new capability.

**A2 · Coverage *by revision*? — NO.**
`FACT` Coverage Analysis scopes are exactly **Latest, Version, Test Plan**, optionally
refined by **Test Environment**. Revision is not a dimension.
<https://getxraydocs.atlassian.net/wiki/spaces/XRAYCLOUD/pages/44565185/Coverage+Analysis>
`FACT` `Requirement Status` is a *calculated current-state* field; a global setting can make
it "always calculate based on the latest test run(s) regardless of which version." Version
scoping runs through the Test Execution's **Fix Version**, not a commit.
<https://docs.getxray.app/display/XRAY/Understanding+coverage+and+the+calculation+of+Test+and+requirement+statuses>
`INFERENCE` Xray answers "is this requirement covered *now*, for release 4.2"; it cannot
answer "was criterion C covered at commit `abc123`." Temporal claim survives — **but Fix
Version is the granularity auditors actually ask at.**

**A3 · Any merge gate? — NO, for Xray, Zephyr Scale, and qTest.**
`FACT` `gh api orgs/Xray-App/repos?per_page=100` → 42 repos: JUnit/TestNG/Playwright
reporters, a Maven plugin, Postman collections, migration scripts, ~25 tutorials. **No
GitHub App, no Action, no Checks-API integration in the org.** `FACT` The Marketplace
listing advertises AI test generation, traceability, BDD, reports, Jenkins/GitLab CI — and
mentions **no** merge gate, PR status check, branch protection, signing, tamper-evidence, or
immutable audit trail. <https://marketplace.atlassian.com/apps/1211769/xray-test-management-for-jira>
`FACT` `xray-action`'s only build controls are `failOnImportError` (default **false**) and
`continueOnImportError` (default **true**) — import errors only, never coverage, no Check.
`FACT` Zephyr ships `SmartBear/zephyr-scale-junit-integration` (upload only); SmartBear's PR
status-check lives in **Collaborator** (code review), not Zephyr. qTest ships
`jenkinsci/qtest-plugin` (upload only).
**Threshold R2-5(c) "blocking gate exists → reject outright": does not fire.** The pivot's
cleanest item — and the one [`security.md`](../docs/spike/security.md) §2.4 requires be a
**customer-run CLI**, a few hundred lines against Xray's existing API.

**A4 · Retention & mutability — retention is DEAD as a differentiator.**
`FACT` Xblend DPA: "the retention period of customer personal data is generally determined
by the customer." <https://www.ideracorp.com/legal/xblend/xblend-data-processing-terms>
`FACT` Test Run archiving threshold is admin-configurable **1 day–2 years**; archived runs
"preserved for historical reference and audit purposes"; only *deleting* Test/Test Execution
issues frees storage. <https://getxraydocs.atlassian.net/wiki/spaces/XRAYCLOUD/pages/44565968>
`FACT` History is **fully mutable**: Test Execution is a standard Jira issue; automated test
status can be **manually overridden** without executing a step; bulk Test Run operations
include **Assign, Archive, Delete, Execute**; REST deletion is the documented
storage-reduction path.
<https://getxraydocs.atlassian.net/wiki/spaces/XRAYCLOUD/pages/44565122/Execute+Tests>
**Consequence:** §5(d) ("retention beyond a 90-day tracker window") **is not sellable against
Xray** — Xray's is already indefinite and customer-controlled; the 90 days was Rovo's.
**Residue item (d) removed.**

**A5 · Signing / attestation — none in Xray. Already sold by Tricentis.**
`FACT` No signing, hashing, attestation, or tamper-evidence in Xray's import schema, Test
Execution docs, Marketplace listing, or `Xray-App/xray-junit-extensions` (whose "evidence"
feature attaches *unsigned* screenshots). Same for Zephyr Scale.
`FACT` **qTest does.** **Tricentis Vera + qTest** ships 21 CFR Part 11 electronic signatures
inside qTest *and Jira*: records are **locked once routed for approval**, the system
"generates auditable electronic records, capturing all associated validation data and audit
history," and Vera 2024.3 extended **author-cannot-approve-their-own-record** to Jira record
types. <https://www.tricentis.com/products/digital-validation-vera>,
<https://www.tricentis.com/blog/introducing-tricentis-vera-2024-3>
`INFERENCE` **The threshold did not anticipate this.** §4 established C3's only plausible
buyer is the regulated one. Vera+qTest is the incumbent *for that buyer* and already sells
"a tamper-evident, non-repudiable record of who asserted that test T covers criterion C,
approved by whom" — §5(a), the claim that carried the price. **Empty against Xray, occupied
against qTest.** `UNVERIFIED` Whether Vera's audit trail is *third-party cryptographically
verifiable* or merely append-only inside Tricentis — the only crack left in A5, cheap to close.

| R2-5 question | Result | Threshold consequence |
|---|---|---|
| (a) `Revision` SCM-validated? | **No — free text** | reject-trigger does **not** fire |
| (b) coverage by revision? | **No — Latest/Version/Test Plan only** | survives |
| (c) merge gate anywhere? | **No — all three upload-only** | reject-trigger does **not** fire |
| (d) retention / deletion? | Customer-determined, no TTL; fully mutable | retention **removed** |
| (e) signing / attestation? | None in Xray — **but Vera+qTest ships it** | attribution **removed** |

`FACT` The literal R2-5 reject-trigger is **not** tripped. `INFERENCE` But the other branch
("all four as predicted → residue is four items") overstates it: A4 and A5 eliminate two.
**Honest count: two — (1) a coverage merge gate, (2) commit-granular coverage history.**

## Test B — does a PR head SHA survive merge?

```bash
# per repo: batch-fetch every PR head ref so a stale clone cannot fake a "missing" SHA
git -C <clone> fetch -q origin '+refs/pull/*/head:refs/spike/pull/*' \
                              '+refs/heads/*:refs/remotes/origin/*'
gh api "repos/<owner>/<repo>/pulls?state=closed&per_page=100&sort=updated&direction=desc" \
  --jq '.[] | select(.merged_at != null) | "\(.number) \(.head.sha)"'
git -C <clone> cat-file -e "<sha>^{commit}"           # unknown SHAs excluded, not counted
git -C <clone> merge-base --is-ancestor <sha> origin/HEAD
```
19 repos attempted, **18 usable, 1,160 merged PRs, 0 unknown SHAs, 0 rate-limit failures**
(5,000/5,000 remaining at finish). `graphify` = NA: its 100 most recent closed PRs contain
**zero** merged ones; excluded rather than counted as a rewrite.

| % survive | repos (merged PRs · surviving) |
|---|---|
| **100** | repomix (94·94), code2prompt (39·39), aider (12·12) |
| 45 / 40 / 17 | serena (66·30), gitdiagram (47·19), stakgraph (89·16) |
| 12 / 11 / 3 / 1 | GitNexus (78·10), claude-context (60·7), grepai (66·2), codegraph (80·1) |
| **0** | bloop (94), opengrok (90), zoekt (82), deepwiki-open (65), potpie (62), sourcebot (57), gitingest (43), codegraphcontext (36) |
| **Aggregates** | **pooled 230/1,160 = 19.83%** · mean-of-repos 23.83% · **median repo 2.0%** |

`FACT` **8 of 18 repos are at exactly 0%**; **15 of 18 lose the majority**; the 3 that don't
preserve **100%**. The distribution is bimodal — a repo either merge-commits everything or
squashes everything — so per-repo counts are the right unit for the round-1 dispute.
`FACT` **15/18 rewrite** vs red team 13/19 vs coordinator 6/19: **the red team is
substantially correct; the coordinator's merge-ratio proxy is refuted**, undercounting by
>2× exactly as `verification-coordinator.md` §2 warned.

**Method validation** (against a false "not found"): `repomix` PR 1771 —
`rev-list --parents -n1 <merge_commit_sha>` returns 2 parents, head SHA is the second,
ancestor **YES** (true merge commit). `potpie` PR 1036 — merge commit has **1 parent**
(squash), head SHA ancestor **NO**. `unknown_sha = 0` across all 1,160 PRs, so no "not
ancestor" result is a clone artifact.

**Threshold R2-1** (*<50% → `gitCommit` is the wrong key; **<20% → "SHA-exact" unsellable →
C3 to reject***). **<50%: tripped decisively** — every aggregation is far below, so
`subject[0].digest.gitCommit` is the wrong key; now `FACT`, no longer `UNVERIFIED`.
**<20%: tripped, by 0.17 points on the pooled figure only.** `INFERENCE` I will not let a
**3-PR margin** carry a reject alone — three more merge commits would read 20.09%, and the
repo-mean (23.83%) sits above. **But** the median repo preserves **2%** and 8/18 preserve
none: for a randomly chosen repository the modal outcome is that *every* artifact keyed to a
PR head SHA is orphaned at merge. On the question the threshold was asking — *can we sell
"SHA-exact"?* — the answer is no.

**Confidence: high on measurement, medium on corpus.** Deterministic, 1,160 trials, zero
unknowns. `UNVERIFIED` The corpus is 19 OSS code-intelligence repos; enterprise monorepos
mandating merge commits could score higher. Not in doubt: a design with **no post-merge
re-attestation path is broken for the majority of repos measured**.

## Bottom line

**The pivot survives as a thesis but not as a business.** Neither pre-committed
reject-trigger fired cleanly — Xray's `Revision` is unvalidated free text (A1), it cannot
compute coverage by commit (A2), and no incumbent can block a PR on coverage (A3) — so on
the letter of R2-5 the residue is real. But it is **two items, not four**. Retention is gone:
Xray's is customer-determined with no vendor TTL, so §5(d) was never sellable against the
right competitor. Attribution and tamper-evidence are gone for the only buyer C3 has —
**Tricentis Vera + qTest already sells 21 CFR Part 11 e-signatures, record locking,
separation of duties, and a full audit history inside Jira**, which is §5(a) restated as a
shipping product. What remains is (1) a merge gate that `security.md` §2.4 requires be a
customer-run CLI over a competitor's API, and (2) commit-granular history, whose key Test B
just removed: **19.83% pooled survival, median repo 2%, 8 of 18 at zero** — while Xray's
Fix-Version scoping answers the question auditors actually ask. `INFERENCE` **My read: no-go
on the current pivot.** A one-feature, open-sourceable CLI over an incumbent's API, with no
accumulating state, no retention edge, no attribution edge, and a temporal claim keyed to an
identifier destroyed by the default merge strategy in 15 of 18 repositories, is not a
company. §7 pre-committed that negative thresholds mean round 3 is a no-go; R2-1 came back
negative on both branches and R2-5 came back nominally positive but materially empty. **Two
cheap `UNVERIFIED` questions could still change this** — whether Vera's audit trail is
third-party cryptographically verifiable or merely append-only inside Tricentis, and whether
the enterprise head-SHA survival rate is materially above 19.83%. Those, not interviews, are
what to buy. Absent both: **no-go.**
