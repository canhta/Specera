# Inventory — cloned repositories and research targets

Snapshot date: **2026-08-04**. Clones are full-history, in `.spike/clones/<repo-name>`
(not committed). Per-repo analysis lives in [`competitors/`](competitors/index.md) —
this file carries only acquisition metadata and machine-checkable facts.

## Open-source clones (19/19 succeeded)

`FACT` — all rows below produced by `git rev-parse` / `git log` / `du` against the
clones on 2026-08-04. Reproduce with `.spike/clone.sh` then the commands in
[§ Verification](#verification).

| Repo | HEAD | Last commit | Commits | Last 6mo | Size | License (from file) |
|---|---|---|---|---|---|---|
| [graphify](competitors/graphify.md) | `00efd6e` | 2026-08-01 | 1342 | **1342** | 27M | Apache-2.0 |
| [GitNexus](competitors/gitnexus.md) | `9eaf2e6c` | 2026-08-03 | 1745 | **1628** | 228M | **PolyForm Noncommercial 1.0.0** |
| [potpie](competitors/potpie.md) | `b5a67742` | 2026-07-30 | 752 | 195 | 90M | Apache-2.0 |
| [codegraph](competitors/codegraph.md) | `49c11fc` | 2026-08-01 | 780 | **744** | 156M | MIT |
| [codegraphcontext](competitors/codegraphcontext.md) | `0aa7017` | 2026-08-03 | 1710 | 1031 | 127M | MIT |
| [stakgraph](competitors/stakgraph.md) | `847d7cdc` | 2026-08-01 | 3451 | 689 | 53M | **none — no LICENSE file** |
| [serena](competitors/serena.md) | `cd04838b` | 2026-08-03 | 3223 | 1135 | 25M | MIT |
| [grepai](competitors/grepai.md) | `c4f294b` | 2026-03-27 | 191 | 51 | 32M | MIT |
| [claude-context](competitors/claude-context.md) | `6fc318b` | 2026-07-14 | 217 | 70 | 37M | MIT |
| [sourcebot](competitors/sourcebot.md) | `97ebcd63` | 2026-08-03 | 1358 | 553 | 102M | **Functional Source License** |
| [zoekt](competitors/zoekt.md) | `2cb19912` | 2026-07-29 | 1940 | 59 | 16M | Apache-2.0 |
| [opengrok](competitors/opengrok.md) | `b9be6fdcaa5` | 2026-06-25 | 7790 | 57 | 610M | **CDDL-1.0** (+6 bundled) |
| [repomix](competitors/repomix.md) | `c6f084be` | 2026-08-03 | 4353 | **1446** | 43M | MIT |
| [aider](competitors/aider.md) | `5dc9490bb` | 2026-05-22 | 13138 | 78 | 216M | Apache-2.0 |
| [gitingest](competitors/gitingest.md) | `4e259a0` | 2025-08-16 | 405 | **0** | 2.8M | MIT |
| [code2prompt](competitors/code2prompt.md) | `ab4fa06` | 2026-06-18 | 679 | 73 | 21M | MIT |
| [deepwiki-open](competitors/deepwiki-open.md) | `b5e7666` | 2026-07-30 | 240 | 31 | 11M | MIT |
| [gitdiagram](competitors/gitdiagram.md) | `364d709` | 2026-07-30 | 337 | 178 | 4.9M | MIT |
| [bloop](competitors/bloop.md) | `431e9e82` | 2024-12-04 | 998 | **0** | 97M | Apache-2.0 |

## Machine-checkable findings

These are established by the table above and require no further analysis.

**`FACT` — Three licenses block commercial reuse of code:**

- `GitNexus` is **PolyForm Noncommercial 1.0.0** (`.spike/clones/GitNexus/LICENSE:1`).
  Non-commercial use only. Specera cannot copy, link, or derive from this code in a
  commercial product. Reading it for ideas is permitted; reusing it is not.
- `stakgraph` ships **no LICENSE file** (verified: no `LICENSE`/`LICENCE`/`COPYING`
  at repo root, HEAD `847d7cdc`). Absent a grant, default copyright reserves all
  rights. Not reusable without written permission from the owner.
- `sourcebot` is under the **Functional Source License**
  (`.spike/clones/sourcebot/LICENSE.md`), a source-available license with a
  competing-use restriction. A code-intelligence platform is plausibly a competing
  use — legal review required before any reuse.

`FACT` — `opengrok` is **CDDL-1.0**, a file-level weak copyleft that is
GPL-incompatible and carries six additional bundled licenses. Usable as a
deployed service; entangling for source reuse.

**`FACT` — Two projects are dormant, one formally dead.** `bloop` is **archived**
(GitHub API `"archived": true`, verified 2026-08-04; archived by the owner on
2025-01-02; `https://bloop.ai` refuses connections). `gitingest` has zero commits
in six months (last 2025-08-16). `aider` shows a sharp slowdown: 78 commits in
six months against 13,138 lifetime.

**`FACT` — Licensing trap in `bloop`'s history.** HEAD (`431e9e82`) is cleanly
Apache-2.0, but commits before 2024-04 contain a **proprietary, seat-licensed**
`server/bleep/src/ee/` tree carrying its own license, recoverable via
`git show 59a7e4a3^:server/bleep/src/ee/LICENSE` ("may only be used in
production, if you… have agreed to… the bloop Subscription Terms of Service").
That directory does not exist at HEAD. Anything borrowed from `bloop` must be
taken from HEAD only — never a historical checkout, an old release tarball, or a
`git log -p` excerpt. This applies to full-history clones specifically, which is
how this spike acquired the repo.

**`FACT` — Four graph projects are very young.** `graphify` (1342 of 1342
commits within six months — the entire history is recent), `codegraph`
(744/780), `GitNexus` (1628/1745), `codegraphcontext` (1031/1710).

`INFERENCE` — The code-graph-for-LLM category materialised within roughly the
last six months and is not consolidated. Basis: the four commit distributions
above, versus the mature lexical search tools (`zoekt` 2026-07-29,
`opengrok` 7790 commits) whose recent activity is maintenance-rate. This cuts
both ways for Specera: the graph layer is not yet owned by anyone, and it is also
being attempted by many teams simultaneously, so a graph alone is unlikely to be
defensible. Tested in [`comparison.md`](comparison.md) and
[`red-team.md`](red-team.md).

## Commercial / closed research targets

No source access. Documentation-based research, files under
[`competitors/services/`](competitors/index.md).

| Product | File |
|---|---|
| Graphify Platform | [services/graphify-platform.md](competitors/services/graphify-platform.md) |
| GitNexus Enterprise | [services/gitnexus-enterprise.md](competitors/services/gitnexus-enterprise.md) |
| Sourcegraph | [services/sourcegraph.md](competitors/services/sourcegraph.md) |
| Augment Code | [services/augment-code.md](competitors/services/augment-code.md) |
| Greptile | [services/greptile.md](competitors/services/greptile.md) |
| CodeRabbit | [services/coderabbit.md](competitors/services/coderabbit.md) |
| DeepWiki / Devin | [services/deepwiki-devin.md](competitors/services/deepwiki-devin.md) |
| GitHub Copilot | [services/github-copilot.md](competitors/services/github-copilot.md) |
| GitLab Duo | [services/gitlab-duo.md](competitors/services/gitlab-duo.md) |
| Atlassian Rovo | [services/atlassian-rovo.md](competitors/services/atlassian-rovo.md) |

## Verification

```bash
.spike/clone.sh                     # idempotent; skips existing clones
cd .spike/clones
for d in */; do n="${d%/}"
  echo "$n $(git -C "$n" rev-parse --short HEAD) \
$(git -C "$n" log -1 --format=%ad --date=short) \
$(git -C "$n" rev-list --count HEAD) \
$(git -C "$n" log --since='6 months ago' --oneline | wc -l)"
done
```

Licenses were read from each repo's license file, not inferred from package
metadata or memory.

`FACT` — That rule caught a real error. GitHub's API reports `GitNexus`'s license
as `NOASSERTION`, while `.spike/clones/GitNexus/LICENSE:1` reads "PolyForm
Noncommercial License 1.0.0" and `gitnexus/package.json:6` declares
`"license": "PolyForm-Noncommercial-1.0.0"`. Anything relying on the GitHub
license field would have recorded the most commercially restrictive repo in this
set as unlicensed-but-unremarkable. Read the file.
