# Reopening check 2 — does head-SHA survival improve in a more mature corpus?

Coordinator, 2026-08-04. Input to [`decision.md`](../docs/spike/decision.md) §5.

## Question

Round 2 measured **19.83%** pooled head-SHA survival (median repo 2.0%) across
1,160 merged PRs in 18 repositories. Those were young AI-tooling repos, where
squash-merge is a common default. `decision.md` §5 left open whether a more
mature corpus would materially exceed that — if it did, the design's
`(work item key, commit SHA)` key might be salvageable.

I do not have access to enterprise-internal repositories. The nearest better
reference class is **large, corporate-operated open source**, which reflects
mature engineering-org practice far better than the original corpus.

## Method

For each repo: 12 most recent merged PRs; for each, `GET /repos/{r}/compare/{default_branch}...{head_sha}`
and count `status` of `behind` or `identical` as survival (head SHA is an
ancestor of the default branch). A `diverged` status means squash or rebase
discarded the head commit.

```bash
gh api "repos/$r/pulls?state=closed&per_page=30" \
  --jq '.[] | select(.merged_at != null) | .head.sha' | head -12
gh api "repos/$r/compare/$base...$sha" --jq .status
```

## Result

| Repo | Survived | Sampled | % |
|---|---|---|---|
| spring-projects/spring-boot | 12 | 12 | **100%** |
| kubernetes/kubernetes | 11 | 12 | **91%** |
| microsoft/vscode | 2 | 12 | 16% |
| hashicorp/terraform | 2 | 12 | 16% |
| elastic/elasticsearch | 0 | 12 | 0% |
| grafana/grafana | 0 | 12 | 0% |
| apache/kafka | 0 | 12 | 0% |
| angular/angular | 0 | 12 | 0% |
| facebook/react | 0 | 12 | 0% |
| golang/go | — | 0 | n/a — see below |

`FACT` **Pooled: 27/108 = 25.0%. Median repo: 0%. Seven of nine repos lose ≥84%
of head SHAs.**

`FACT` `golang/go` returned zero merged GitHub PRs in the sample — the Go project
reviews through Gerrit, not GitHub pull requests.

## Verdict: **NO-GO STANDS** on this question

`INFERENCE` The mature corpus does **not** materially exceed the startup corpus.
Pooled survival rises from 19.83% to 25.0% — the same order of magnitude — and
the **median repository is worse (0% vs 2.0%)**. The distribution is bimodal in
both corpora: a small number of merge-commit shops preserve nearly everything,
and everyone else preserves almost nothing. A design keyed on the head SHA works
excellently for Kubernetes and Spring Boot and fails completely for Elasticsearch,
Grafana, Kafka, Angular, and React.

`INFERENCE` Two secondary findings that make the picture slightly worse, not
better:

1. **Bimodality defeats an averaged design.** Because outcomes cluster at 0% and
   ~100% rather than spreading around a mean, a product cannot be tuned to a
   typical customer — it either works at a given org or it does not, determined
   by a merge-strategy setting the vendor does not control and the customer will
   not change for a procurement trial.
2. **Not every org uses GitHub PRs at all.** `golang/go` on Gerrit is a reminder
   that the assumed substrate (GitHub PR + head SHA) is itself an adoption
   constraint, not a given.

`UNVERIFIED` What this still does not measure: genuinely private enterprise
monorepos, which may differ from corporate OSS in either direction. Settling it
requires the same ancestry test inside 2–3 real customer estates. `INFERENCE`
Given that two independent corpora now agree within ~5 points, the burden of
proof has shifted — a third measurement would need to be strikingly different to
change the conclusion, and the tree-digest fallback (never designed or costed)
would have to be built regardless.

## Consequence

The reopening condition in `decision.md` §5 item 2 is **not met**. This does not
by itself sustain the no-go — it removes one of the two ways out of it.
