# S1 — Monorepo, language, and build system

## 0. Liveness / licence (every dependency recommended below)

`FACT` — `gh api repos/<r>` on 2026-08-04. `archived=false` on every row.

| Repo | SPDX | ★ | Pushed | Issues | Verdict |
|---|---|---|---|---|---|
| `pnpm/pnpm` | MIT | 35953 | 2026-08-04 | 2500 | **adopt** — workspaces |
| `vitest-dev/vitest` | MIT | 16906 | 2026-08-03 | 405 | **adopt** — tests |
| `biomejs/biome` | Apache-2.0 | 25485 | 2026-08-04 | 516 | **adopt** — lint+format |
| `changesets/changesets` | MIT | 12218 | 2026-08-03 | 274 | **adopt** — versioning |
| `cucumber/gherkin` | MIT | 386 | 2026-08-04 | 42 | **adopt** — low ★, but canonical + MIT + vendorable |
| `cucumber/cucumber-js` | MIT | 5379 | 2026-08-03 | 36 | **adopt** — run-result ingest |
| `modelcontextprotocol/typescript-sdk` | §0.1 | 13053 | 2026-08-04 | 534 | **adopt** |
| `tree-sitter/tree-sitter` | MIT | 26533 | 2026-08-03 | 137 | adopt (WASM build only) |
| `astral-sh/uv` | Apache-2.0 | 88303 | 2026-08-04 | 2837 | adopt — Python provider subprocess only |
| `oxc-project/oxc` | MIT | 22209 | 2026-08-04 | 749 | optional, only if Biome is too slow |
| `ory/polis` (was `boxyhq/jackson`) | Apache-2.0 | 2257 | 2026-07-27 | 23 | **conditional** — §0.1 |
| `nrwl/nx` | MIT | 29187 | 2026-08-04 | 486 | **reject** — §2 |
| `vercel/turborepo` | MIT | 30851 | 2026-08-04 | 17 | defer; additive over pnpm later |
| `moonrepo/moon` | MIT | 4029 | 2026-07-31 | 107 | reject — 4k ★, single vendor |
| `bazelbuild/bazel` | Apache-2.0 | 25668 | 2026-08-03 | 1904 | reject — cost ≫ benefit at this size |
| `semantic-release/semantic-release` | MIT | 23940 | 2026-08-04 | 403 | reject — single-package model |
| `kuzudb/kuzu` | MIT | 4027 | **2025-10-10** | 329 | `archived=true` — re-confirmed dead |

**No copyleft anywhere in the recommended set.** No constraint on Specera's own licence.

### 0.1 Licences read from the file, not the API

- `FACT` **MCP TypeScript SDK** — API says `NOASSERTION`. `gh api repos/modelcontextprotocol/typescript-sdk/contents/LICENSE`: *"undergoing a licensing transition from the MIT License to the Apache License, Version 2.0… contributions… not yet granted explicit permission to relicense remain licensed under the MIT License."* Both permissive → no consequence.
- `FACT` **BoxyHQ Jackson no longer exists under that name.** `curl -sI https://github.com/boxyhq/jackson` → `location: https://github.com/ory/polis`. LICENSE file read: plain Apache-2.0. That is a **governance change** (BoxyHQ → Ory), not a rename — the brief was right to demand the check. Licence is fine; 2257★ under a new owner is thinner than assumed. `UNVERIFIED` whether the enterprise SAML/SCIM surface stayed ALv2 post-transfer.

## 1. Primary language — decision

> **TypeScript on Node 24 LTS ("Krypton") for everything Specera writes.
> Polyglot only across process boundaries, never inside the build.**

`FACT` The polyglot question dissolves on inspection — every non-TS asset already exposes a **process-level contract**, so none forces a host language:

| Asset | Lang | Verified integration contract |
|---|---|---|
| `graphify` | Py | `graphify/ARCHITECTURE.md` — every extractor returns `{"nodes":[…],"edges":[{…,"confidence":"EXTRACTED\|INFERRED\|AMBIGUOUS"}]}`, schema-checked by `validate.py` before `build_graph()`. **A JSON contract, not a library API.** |
| `serena/solidlsp` | Py | console script + MCP server — `serena/pyproject.toml` `[project.scripts] serena = "serena.cli:top_level"`. stdio. |
| `zoekt` | Go | `sourcebot/Dockerfile` builds it in a `golang:1.25-alpine` stage; `sourcebot/supervisord.conf` runs `zoekt-webserver … -rpc` as its own process; TS calls it over gRPC stubs generated into `sourcebot/packages/web/src/proto/zoekt/…`. **The pattern to copy.** |
| `cucumber/gherkin` | 12 langs | `@cucumber/gherkin` 42.0.0 MIT on npm; `gherkin-official` 42.0.0 on PyPI. |

`FACT` **Rust is disqualified for slice 1.** `gh api repos/cucumber/gherkin/contents` lists `c cpp dart dotnet elixir go java javascript perl php python ruby` — **no Rust implementation exists**. `cucumber-rs/cucumber` (Apache-2.0, 737★) is a third-party *runner*, not the parser. Starting the Gherkin spine on an unofficial parser is a bad trade.

`FACT` Per-language liveness (last commit touching each dir): `javascript 2026-08-03` · `java 2026-08-03` · `python 2026-07-28` · `dotnet 2026-07-20` · `go 2026-07-19` · `ruby 2026-07-19`. **JS is the most recently touched implementation**; Python is a close second. Both are safe.

Why TS beats the runner-up (Python):

1. `FACT` Every mature end-user CLI+MCP in the corpus that ships to the IDE/agent audience is TS on npm: `repomix` (27616★), `codegraph`, `GitNexus`, `claude-context`. `npx specera` is the lowest-friction install for that audience.
2. The dashboard is TS regardless. Python core buys a permanent language boundary *inside* the product and gains nothing — the ontology/zod package can only be shared with the dashboard if core is TS.
3. `FACT` **Zero-native-build is achievable in TS and not in Python.** `repomix/package.json` and `codegraph/package.json` both use `web-tree-sitter` + `*tree-sitter-wasms` — no compiler on the install path. `graphify/pyproject.toml` pulls 26 native `tree-sitter-*` bindings. `codegraph/BUNDLING.md`: *"dropping better-sqlite3 left zero native addons… any target builds on any OS."* Enterprise install friction, gone.
4. `FACT` `node:sqlite` verified locally on Node v24.18.0 → `DatabaseSync,StatementSync,Session,constants,backup`; `CREATE TABLE` succeeded. Built-in real SQLite with WAL, on LTS, zero dependencies.

**Polyglot cost, priced.** Each of the three subprocess providers costs a bootstrap/detection path, a version-pin matrix, a Docker layer and a CI leg — ~1 engineer-week up front plus a recurring upgrade tax. Worth paying **only** because all three are optional (slices 4+) and none is needed for slices 1–3. `INFERENCE` If any becomes mandatory for slice 1, revisit: day-one install must stay `npx specera` with no Python and no Go on the machine.

**Runner-up: Python** (uv + hatchling, as `potpie`, `serena`, `graphify` all do). **What would change my mind:** (a) the team is Python-native and TS is a hiring constraint; (b) slice 1 needs in-process access to graphify internals rather than its JSON contract; (c) reusing `potpie/context-core/…/ontology.py` proves to need live Python rather than a one-time transliteration to zod. **Rust: reject for the product**, keep as an optional napi kernel (§4).

## 2. Monorepo tooling — decision

> **pnpm workspaces. No Nx, no Turborepo, no Bazel, no moon, no Lerna.**

`FACT` **0 of 19 clones use a monorepo build orchestrator.** Searched all clones for `nx.json`, `turbo.json`, `moon.yml`/`.moon`, `WORKSPACE`, `MODULE.bazel`, `lerna.json`, `rush.json` → **zero hits**. Only two use any workspace manager:

| Repo | Tool | Shape |
|---|---|---|
| `sourcebot` | Yarn 4.7.0 workspaces, `["packages/*"]` | 7 packages (`backend db queryLanguage schemas setupWizard shared web`). Orchestration is literally `yarn workspaces foreach --all --topological run build`. An enterprise self-hosted platform with SSO, Prisma, Next.js — **and no build tool.** |
| `claude-context` | pnpm 10, `pnpm-workspace.yaml` | 4 packages: `core mcp vscode-extension chrome-extension`; `workspace:*` in `packages/mcp/package.json`; `pnpm -r --filter` for topological builds. **Our exact shape.** |
| `GitNexus` | **none** — only *calls itself* a monorepo | `package.json` has **no `workspaces` field**; `package-lock.json` `packages` map holds only the root; linkage is `"gitnexus-shared": "file:../gitnexus-shared"`. The convention-only failure mode to avoid. |

Why pnpm over Nx, the popular default:

- `FACT` **Nx shipped malicious packages.** `GHSA-8mjq-32x3-22qf` — *"Malicious versions of Nx were published"*, severity **critical**, 2025-09-25 (also `GHSA-g2r8-wvmj-jf5w`, medium, 2026-07-31). A build orchestrator sits at the root of the dep tree with postinstall/plugin execution rights — the highest-value supply-chain target in the repo. Brief rule 4 applies directly.
- `INFERENCE` Nx's and Turborepo's headline value is **remote caching**, a vendor SaaS (Nx Cloud / Vercel). For an **air-gapped, no-phone-home** product that is a non-feature at best and a compliance question at worst.
- pnpm delivers what we need with no orchestrator: `workspace:*` (link-time enforcement of the package graph), `pnpm -r --filter` (topological builds), and a **strict non-flat `node_modules`** that turns phantom dependencies into resolution failures — which is exactly what makes the §3 connector contract enforceable rather than aspirational.
- **Add Turborepo later if at all** — it layers over pnpm. Trigger: CI wall-clock > 10 min.

Python side: `uv` for provider subprocesses only. `FACT` `potpie/pyproject.toml` `[tool.uv.workspace] members = ["potpie/context-core", "potpie/context-engine", "potpie/integrations", "potpie/parsing", "potpie/sandbox"]` — a live 5-member uv workspace if Python ever grows past one package.

## 3. Repository layout

Two mechanisms make the connector contract **structural**, not conventional: (a) `connectors/*` are separate pnpm packages declaring `@specera/connector-sdk` and **never** `@specera/core`, and pnpm's strict store makes reaching past the SDK a resolution failure; (b) the SDK is **published to npm independently**, so an out-of-tree third-party connector is the same artifact as a first-party one. Discovery by name convention (`specera-connector-*`) + manifest — adding a connector never edits core.

```
specera/
├── pnpm-workspace.yaml            # packages/*, packages/providers/*, connectors/*, e2e
├── package.json                   # private root; scripts only
├── packages/
│   ├── ontology/                  # @specera/ontology — node/edge types, EXTRACTED|INFERRED|AMBIGUOUS enum,
│   │                              #   zod + JSON Schema. Depends on NOTHING. Transliterated from
│   │                              #   potpie/context-core/src/potpie_context_core/ontology.py (Apache-2.0)
│   ├── connector-sdk/             # @specera/connector-sdk — THE stable contract. deps: ontology only
│   ├── graph/                     # @specera/graph — storage + query; provenance filter is a query
│   │                              #   PRECONDITION, high-confidence by default (see §6 risk)
│   ├── core/                      # @specera/core — static typed ingestion phase DAG; merge-commit keying
│   ├── gherkin/                   # @specera/gherkin — @cucumber/gherkin parse + cucumber-js result ingest
│   ├── policy/                    # @specera/policy — rules over the graph, evaluated from the BASE branch
│   ├── mcp/                       # @specera/mcp — MCP server (stdio + http)
│   ├── cli/                       # specera — the published bin; the only package with `bin`
│   ├── dashboard/                 # @specera/dashboard
│   └── providers/                 # subprocess adapters; each owns bootstrap, version pin, health check
│       ├── graphify/ (Py, JSON stdout)  solidlsp/ (Py, stdio)  zoekt/ (Go, gRPC)
├── connectors/ github/ jira/ grafana/ confluence/     # deps: @specera/connector-sdk ONLY
├── e2e/                           # cross-package tests; owns no source
├── docs/
├── deploy/ compose/  helm/        # Chart.yaml appVersion templated from the release version
└── .github/workflows/
```

`FACT` **Do not make the ingestion pipeline pluggable.** `GitNexus/ARCHITECTURE.md:119`: *"`runner.ts` — static phase graph, no plugins, compile-time type safety"*, a 19-phase DAG whose runner *"filters the results map to prevent hidden coupling."* `INFERENCE` The right seam is the **I/O boundary** (per-vendor auth, pagination, rate limits, schema mapping = connectors), not the **transform pipeline** (which wants a typed, topologically-sorted, statically-known DAG). Conflating the two is how plugin architectures rot.

## 4. Build, test, lint, typecheck, CI, install

| Concern | Choice | Evidence |
|---|---|---|
| Build | `tsc` project references per package; no bundler for libs | `repomix`: `"build": "rimraf lib && tsc -p tsconfig.build.json"`. Every sourcebot package: `"build": "tsc"`. Nobody in the corpus bundles libraries. |
| Test | **vitest** | `FACT` 5/5 convergence: repomix, codegraph, GitNexus, sourcebot, claude-context. Playwright for dashboard e2e (GitNexus, stakgraph). |
| Lint+format | **Biome** (one tool, replaces eslint+prettier) | repomix runs `biome check --write` + oxlint + `tsc --noEmit` + secretlint. GitNexus still runs eslint+prettier+husky+lint-staged — the older, heavier setup. Take repomix's. |
| Typecheck | `tsc --noEmit` as its own CI job | `repomix/.github/workflows/ci.yml` splits `lint-biome`/`lint-oxlint`/`lint-ts`/`lint-secretlint` — parallel, and a failure names itself. |
| Secrets | `secretlint` in CI **and** on the product's own scan path | repomix depends on `@secretlint/core` at runtime, not just in CI — relevant to the no-egress posture. |
| CI hardening | actionlint + **zizmor** + **pinact** (all actions SHA-pinned) + CodeQL + `typos` + `permissions: contents: read` + `persist-credentials: false` | `repomix/.github/workflows/ci-quality.yml`, `ci.yml` — e.g. `uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`. **Best CI security posture in the corpus, nearly free to copy.** |
| Deps | Renovate | `repomix/.github/renovate.json5` |

**Single-command install — two tiers from one artifact set, both proven in-corpus:**

1. **`npx specera` / `npm i -g specera`** — works because there are **zero native addons**: `web-tree-sitter` (WASM) for parsing, `node:sqlite` (built-in) for storage.
2. **`curl -fsSL … | sh`, no Node required** — adopt codegraph's bundled-Node pattern verbatim (`codegraph/BUNDLING.md`, `scripts/build-bundle.sh`, `install.sh`/`install.ps1`): ship `node` + `lib/dist` + pure-JS `node_modules` per platform, plus an npm **thin shim** whose per-platform bundles are `optionalDependencies` gated on `os`/`cpu`. Because nothing compiles, *the whole 6-target matrix builds on one Linux runner*. Contrast `stakgraph/install.sh`, which needs a 5-leg `cargo build`/`cross` matrix (`build-cli.yml`) for the same outcome — the cost of Rust, made concrete.

`FACT` **The escape hatch has precedent.** codegraph re-added a Rust napi kernel at 1.5.0 (`codegraph-kernel/Cargo.toml`: `napi 3`, `crate-type = ["cdylib"]`) with per-file WASM fallback and prebuilds from a 4-runner matrix. "TS now, native kernel later" does **not** forfeit zero-native-*install* — but it adds a permanent grammar-parity gate (`__tests__/kernel-*.test.ts`).

## 5. Versioning and release

> **Changesets, `fixed` (lockstep) across every user-visible package. One GitHub Release fans out to npm + GHCR + Helm. npm auth via OIDC, no token.**

`FACT` The drift failure mode is already visible in-corpus: `claude-context/.github/workflows/release.yml` publishes each package with a separate hand-written `pnpm --filter … publish --no-git-checks` step and **no version tool** — core, mcp and root all sit at `0.1.15`, kept in step by hand.

1. PR adds a changeset. `fixed: [["@specera/*", "specera"]]` → one version for everything a user can see. Independent versioning is reserved for `@specera/connector-sdk`, whose SemVer must mean something to third-party connector authors.
2. Release PR merges → tag + **GitHub Release published**. That event is the *single* trigger. `FACT` `repomix/.github/workflows/docker.yml`: `on: release: types: [published]`, matrix `linux/amd64` + `linux/arm64` (native arm runner) + `linux/arm/v7` (QEMU).
3. npm publish via **OIDC trusted publishing** — no `NPM_TOKEN` anywhere. `FACT` both `repomix/npm-publish.yml` (`permissions: id-token: write`, `npm publish --provenance --access public`) and `codegraph/release.yml` (*"npm auth is OIDC trusted publishing (no NPM_TOKEN)"*) do this. Also copy codegraph's **post-publish registry verification loop** — `npm publish` can report success without persisting.
4. Docker tag and `deploy/helm/Chart.yaml` `appVersion` are both templated from that same version in the same job. **No drift is possible because no version is typed twice.**
5. Supply-chain proof: `actions/attest-build-provenance` + `SHA256SUMS` (codegraph `release.yml`); `npm audit signatures` (repomix).

**Rejected:** `semantic-release` — alive and MIT, but models one package per repo; in a monorepo it fights changesets rather than complementing it. **Rejected:** manual (proven to drift, above).

`FACT` **Nothing in the corpus ships a Helm chart** — `find . -name Chart.yaml` across all 19 clones returns nothing; 11 ship `docker-compose` (sourcebot, stakgraph, serena, GitNexus, bloop, …). `INFERENCE` Compose is table stakes, Helm is tier two — Greptile documents both (`evidence-greptile.md:137`: air-gapped, Compose or K8s Helm `greptileai/akupara`). Ship Compose in v1, Helm when the first K8s customer asks. sourcebot's `supervisord.conf` (zoekt + web + backend in one container) is the cheap middle option.

## 6. Verdicts, risk, gaps

| Area | Decision | Runner-up |
|---|---|---|
| Language | **TypeScript, Node 24 LTS**; polyglot only as subprocess providers | Python (uv + hatchling) |
| Monorepo tool | **pnpm workspaces, nothing else** | Yarn 4 workspaces (sourcebot's actual choice) |
| Layout | `packages/*` + `connectors/*`; SDK-only deps for connectors; static typed ingestion DAG | — |
| Build/test/lint | `tsc` refs · vitest · Biome · `tsc --noEmit` · zizmor/pinact/actionlint/secretlint | eslint + prettier (GitNexus's older stack) |
| Install | `npx specera` (zero native addons) + bundled-Node `curl \| sh` | Rust single binary (5-leg cross-compile matrix) |
| Release | Changesets `fixed` + one GitHub Release → npm/GHCR/Helm, OIDC publish | semantic-release |

**Single biggest risk.** TypeScript in the graph query hot path. The brief requires provenance filtering *by default at query time* — a per-edge predicate on the hottest loop in the system. If Node becomes the bottleneck, the escape hatch (napi kernel, as codegraph did at 1.5.0) reintroduces the native-build friction that justified TS. It can be done without breaking zero-native-*install*, but costs a cross-platform prebuild matrix and a parity gate forever. **Experiment that settles it:** before slice 2, benchmark a provenance-filtered 3-hop traversal over a synthetic 10⁶-edge graph on `node:sqlite` with WAL. If p95 > 200 ms, the *storage layer* — not the language — is what must change first.

**Could not verify**

- `UNVERIFIED` Helm chart shape for this product class — no `Chart.yaml` exists in any of the 19 clones, so the §5 Helm step is designed, not evidenced.
- `UNVERIFIED` TypeScript 7. `repomix/package.json` pins `"typescript": "^7.0.2"` (plus `vite ^8`, `vitest ^4`). Not run against our toolchain — pin TS 5.x on day one, treat 7 as a deliberate later migration.
- `UNVERIFIED` Whether `node:sqlite` has left the experimental stability index on Node 24. It imports and runs (v24.18.0) and codegraph ships on it, but `codegraph/src/extraction/wasm-runtime-flags.ts:45` still passes `--disable-warning=ExperimentalWarning`. Confirm before it becomes load-bearing for storage.
- `UNVERIFIED` `ory/polis` post-transfer maintenance, and whether the enterprise SAML/SCIM surface stayed Apache-2.0 after the BoxyHQ→Ory move. Licence file is clean ALv2 today; the governance question is open.
- `UNVERIFIED` Bus factor of the two best packaging references (`repomix` — Kazuki Yamada; `codegraph` — single author). Immaterial: we copy their *workflows*, we do not depend on their *packages*.
