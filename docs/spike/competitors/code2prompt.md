# code2prompt

A Rust CLI + TUI (plus a Python binding) that walks a **local** directory with the `ignore` crate, counts tokens per file with `tiktoken-rs`, and renders the selected files through a Handlebars template into Markdown, JSON, or XML.

## 1. Verdict

Component, not a competitor — but the least commodity of the three packing tools on *prompt construction*, and the only one with **zero network egress by design**. Its distinguishing asset is templating: a Handlebars engine with 13+ built-in task-specific prompt templates compiled into the binary (`crates/code2prompt-core/src/builtin_templates.rs:29-60+`), three output formats, and per-file token counts rendered as an ASCII "token map" so a human can see where the budget goes. Its second asset, landed in the newest commit, is `entity_map.rs` — tree-sitter entity extraction producing a `code_map` of functions/classes/methods with line ranges and signatures. What kills it: **it is local-path only** — no remote repo fetch at all (`crates/code2prompt/src/args.rs:24-26` takes a `PathBuf`) — it does no secret detection, its entity map is **off by default behind a compile-time Cargo feature**, and like its peers it has no index, no incremental update, and no accuracy measurement.

## 2. Core architecture and unique mechanism

Full walk → filter → per-file process → tokenize → template render. Nothing persists between runs.

**Traversal and filtering (two layers).** `FACT`
- The `ignore` crate's `WalkBuilder`: `crates/code2prompt-core/src/path.rs:11, 97-113` with `.hidden(!config.hidden)`, `.git_ignore(!config.no_ignore)`, `.follow_links(config.follow_symlinks)` — git-aware and `.gitignore`-respecting by default.
- On top, its own include/exclude glob engine `FilterEngine` (`crates/code2prompt-core/src/filter.rs`) with brace expansion via `bracoxide::explode` (`filter.rs:70-76`) and exclude-takes-precedence semantics (`filter.rs:139-152`).
- **There is no hardcoded default-ignore list** comparable to gitingest's 138 patterns or repomix's 86. Exclusion depends entirely on the user's `.gitignore` plus whatever `--exclude` globs they pass. `FACT` (absence in `filter.rs` / `path.rs`)

**Format-aware file processors** — the quiet good idea. `crates/code2prompt-core/src/file_processor/` has dedicated handlers for `csv.rs`, `tsv.rs`, `jsonl.rs`, `ipynb.rs`; per `file_processor/mod.rs:1-5` these "extract the schema rather than raw data where applicable... schema + sample for CSV, code cells for Jupyter notebooks". `FACT` A 40 MB CSV becomes a header plus a sample instead of 10M tokens of data.

**Token counting.** `tiktoken-rs` (`crates/code2prompt-core/src/tokenizer.rs:6`) with **five selectable encodings** via a `TokenizerType` enum (`tokenizer.rs:26-39`): `O200kBase`, `Cl100kBase` (default), `P50kBase`, `P50kEdit`, `R50kBase`. `CoreBPE` instances are built lazily and cached process-wide in a `OnceLock` (`tokenizer.rs:69-73`). Counts are **both per-file and aggregate** — per-file counts are cached in the session and summed (`crates/code2prompt-core/src/session.rs:393-394, 430-447`, `calculate_token_count_from_cache`) and rendered as a per-file/per-directory ASCII bar chart (`crates/code2prompt/src/token_map.rs`, `crates/code2prompt-core/src/analysis.rs` `TokenMapEntry`). `FACT`

**Entity map (tree-sitter), new in HEAD.** `FACT` (verified by reading `crates/code2prompt-core/src/entity_map.rs:1-50` and `Cargo.toml:15-30`)
- Landed as `1cab012 feat(core): entity-level code map via sem-core (#315)`, merged in HEAD `ab4fa06`.
- Gated behind an **optional Cargo feature**: `crates/code2prompt-core/Cargo.toml:19-23` — `default = []`, `entity-map = ["dep:sem-core"]`. The comment gives the reason: "sem-core pulls in tree-sitter grammars for many languages; users who don't need the code map pay no build cost." With the feature off, `extract_entities` returns `Vec::new()` (`entity_map.rs:104-107`).
- It does not embed its own grammars: it delegates to the external crate `sem-core` v0.13 (`Cargo.toml:29`) and its `parser::plugins::create_default_registry()` (`entity_map.rs:52,59`).
- `EntitySummary` (`entity_map.rs:20-35`) carries exactly `name`, `kind` ("function"/"class"/"method"), `start_line`, `end_line`, `signature` (first line of the entity, trimmed — `entity_map.rs:76-80`), and `parent` (enclosing class for a method — `:81-83`). The doc comment states the design intent explicitly: "a deliberately small projection of sem-core's internal entity type: it carries only what a prompt template needs... not source bodies or content hashes."
- Exposed to templates two ways: per-file as `FileEntry.entities` and as a top-level `code_map` aggregate (`FileCodeMap`, `entity_map.rs:38-41`), so a prompt can carry an outline **instead of** full file bodies.
- **No relationships.** `parent` is the only edge, and it is containment, not a call or import. There is no graph, no ranking, no cross-file link. `FACT`

**Templating.** Handlebars (`crates/code2prompt-core/src/template.rs:35, 69-77`, `use handlebars::{Handlebars, no_escape}`). `OutputFormat` = `Markdown` (default) | `Json` | `Xml` (`template.rs:220-228`). Built-ins: `default_template_md.hbs`, `default_template_xml.hbs`, plus 13 task templates in `crates/code2prompt-core/templates/` — `refactor.hbs`, `fix-bugs.hbs`, `write-git-commit.hbs`, `find-security-vulnerabilities.hbs`, CTF-solver variants — all `include_str!`'d into the binary (`crates/code2prompt-core/src/builtin_templates.rs:29-60+`). `FACT` The TUI ships a template editor and picker (`crates/code2prompt/src/widgets/template/editor.rs`, `picker.rs`).

**Git metadata for prompts.** `crates/code2prompt-core/src/git.rs` reads **local** repo diffs and logs and feeds them into templates. It does no remote fetching. `FACT`

**Crates** (`crates/`):
- `code2prompt-core` v4.3.0 (`Cargo.toml:3`) — the engine: `filter.rs`, `path.rs`, `file_processor/`, `tokenizer.rs`, `template.rs`, `builtin_templates.rs`, `git.rs`, `selection.rs`, `sort.rs`, `analysis.rs`, `session.rs`, `entity_map.rs`.
- `code2prompt` — CLI + ratatui TUI (`args.rs`, `tui.rs`, `widgets/`, `view/`, `config.rs`, `clipboard.rs`, `token_map.rs`).
- `code2prompt-python` — PyO3 bindings exposing `PyCode2PromptSession` (`src/python.rs`).

## 3. Strongest capabilities

- **Task-specific prompt templates as first-class shipped artifacts** — 13+ Handlebars templates compiled in (`builtin_templates.rs:29-60+`), including `find-security-vulnerabilities.hbs` and `write-git-commit.hbs`. No other tool in this category ships a prompt library. `FACT`
- **Per-file token counts plus a visual token map** (`crates/code2prompt/src/token_map.rs`, `analysis.rs`), with five encodings selectable (`tokenizer.rs:26-39`). This is the only one of the three with counts granular enough to *drive* inclusion decisions. `FACT`
- **Schema-not-data processors for structured formats** (`file_processor/{csv,tsv,jsonl,ipynb}.rs`, rationale at `mod.rs:1-5`). `FACT`
- **Fully offline / air-gapped.** No remote fetch, no LLM client, no telemetry. The `entity-map` dependency comment specifically notes sem-core "is offline and carries no telemetry (that lives in the sem CLI, not the library), so this keeps code2prompt fully air-gapped" (`Cargo.toml:26-28`, verified). `FACT`
- **Interactive TUI for file selection** (`crates/code2prompt/src/tui.rs`, `widgets/`) with a memoized selection engine (`selection.rs:38-39, 63-69`) — a human-in-the-loop context builder rather than a batch dump.
- **Heavily tested core.** 15 test files / 3,740 lines under `crates/*/tests/`, with `crates/code2prompt-core/tests/filter_test.rs` alone running 600+ lines of include/exclude glob cases and `path_test.rs` covering hidden-file/walk behaviour. `FACT`
- **Actively developed**: 73 commits in the last 6 months, HEAD `ab4fa06` dated 2026-06-18. `FACT`
- MIT licensed (`LICENSE:3`). `FACT`

## 4. Critical weaknesses

- **No secret detection or redaction.** `grep -rni 'secret|redact|credential'` across `crates/**/*.rs` returns only test fixtures using `".secret/secret.txt"` as an arbitrary hidden-dir name (`crates/code2prompt-core/tests/filter_test.rs:14-633`, `path_test.rs:153,166`). `FACT`
- **No default ignore list at all** (`filter.rs`, `path.rs`). Worse than gitingest here: if a repo's `.gitignore` does not cover `.env`, code2prompt will pack it. The two failure modes compound — no denylist *and* no scanner.
- **The entity map is off unless you recompile.** `default = []` (`Cargo.toml:19-20`, verified). A user installing from crates.io or a release binary gets `extract_entities` returning an empty vector. The headline structural feature is not in the default product. `FACT`
- **Entity extraction is delegated and thinly tested.** One inline test, `extracts_rust_entities` (`entity_map.rs:113-120`) — a single language for a feature whose whole value is multi-language coverage. Which grammars actually work is a property of `sem-core` v0.13, not of this repo, and is unverified here. `UNVERIFIED` — verifying requires reading `sem-core`'s grammar registry, which is not vendored in this checkout.
- **Local paths only.** `crates/code2prompt/src/args.rs:24-26` — `pub path: PathBuf`, default `"."`. No clone, no GitHub API, no URL input. `crates/code2prompt-core/src/git.rs` reads local git metadata only. The user must clone first. `FACT`
- **No cross-file relationships, no ranking.** Files appear in sort order (`sort.rs`); the entity map's only edge is `parent` containment (`entity_map.rs:33-35`). Nothing connects a call to a definition.
- **No persistence, no incremental update.** Every run does a full walk (`path.rs:97-113`). All caching is in-process and dies with the process: selection memoization (`selection.rs:38-39`, cleared on filter change at `:171, 238, 259`), per-file token counts (`session.rs:393-394, 446-447`), tokenizer `OnceLock` (`tokenizer.rs:69-73`). `FACT`
- **Quality is unmeasured.** `grep -rni "benchmark|criterion"` outside `target/` → no hits. No Criterion harness, no accuracy eval, no golden outputs. `FACT`
- **The MCP server is not in this repo.** `README.md:36, 84` advertise "🤖 MCP Server" as a product surface and `llms-install.md` is its install guide, but `llms-install.md:22` points at a **separate third-party repo**, `https://github.com/odancona/code2prompt-mcp`. No `mcp`/`rmcp` dependency or server code exists in `crates/`. `FACT` — the advertised surface is someone else's maintenance burden.

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements / PRD | No | Nothing. |
| Jira / work tracking | No | Nothing. |
| Architecture / ADR | Partial | The `code_map` aggregate (`entity_map.rs:38-41`) is a structural outline — but it is a flat entity list with containment only, off by default, and never written as a document. |
| Implementation | No | Emits a prompt; applies no edits and calls no model. |
| PR review | Partial | `crates/code2prompt-core/src/git.rs` injects local diffs/logs into templates, and `templates/write-git-commit.hbs` is a shipped prompt for commit-message generation. Raw material, no review logic. |
| Test generation | No | No test-related template or logic. |
| Security / pentest | Partial | `templates/find-security-vulnerabilities.hbs` is a *prompt* asking a model to look for vulnerabilities. There is no scanner, no rule set, and no secret detection in the tool itself (§4). |
| Release | No | Nothing. |
| Monitoring / incidents | No | Nothing. |
| Maintenance / knowledge | No | Output is a one-shot prompt string. No persistence, no versioning, no staleness concept. |

## 6. Security, deployment, and license

- **Deployment**: a Rust binary (`crates/code2prompt/Cargo.toml:55-57`), a library crate `code2prompt_core` v4.3.0, and a PyO3 Python module (`crates/code2prompt-python/src/python.rs`). No server, no service, no auth, no tenancy. Runs as the invoking user against a local directory.
- **Network egress: none.** No HTTP client, no LLM SDK, no telemetry, no remote fetch anywhere in `crates/`. This is the strongest privacy posture of any tool in this group and is explicitly a design goal (`crates/code2prompt-core/Cargo.toml:26-28`, verified). `FACT`
- **Secrets handling**: none (§4). Combined with no default ignore list, this is the weakest secret posture of the three packing tools.
- **Prompt-injection surface**: the output *is* a prompt, assembled by Handlebars with `no_escape` explicitly enabled (`template.rs:35`). Repo content — including any instruction-shaped text in a README or comment — is interpolated verbatim into the template. There is no sanitisation. `FACT` `no_escape` is correct for producing readable code in a prompt and simultaneously means nothing is neutralised.
- **License**: MIT — `.spike/clones/code2prompt/LICENSE:3`, "Copyright (c) 2024 Mufeed VH". `FACT` (verified) Fully permissive. **Transitive constraint to check before vendoring `entity_map.rs`:** it depends on `sem-core` v0.13 from `Ataraxy-Labs/sem` (`entity_map.rs:1`, `Cargo.toml:29`), whose license is not in this checkout, and which itself bundles tree-sitter grammars with their own upstream terms. `UNVERIFIED` — resolve by reading `sem-core`'s own LICENSE and its grammar manifest.

## 7. Ideas to adopt or avoid

### Adopt

- **Format-aware processors that emit schema instead of data** (`crates/code2prompt-core/src/file_processor/{csv,tsv,jsonl,ipynb}.rs`, rationale `mod.rs:1-5`). Specera's ingestion should classify by file type and apply a per-type reducer — CSV → header + N sample rows, notebook → code cells only, lockfile → dependency list — before any token is spent. This is a large, cheap win that neither `repomix` nor `gitingest` implements.
- **The `EntitySummary` projection shape** (`entity_map.rs:20-35`): `name`, `kind`, `start_line`, `end_line`, `signature`, `parent` — and the explicit decision *not* to carry bodies or content hashes. It is the right minimum for an outline. Specera should use exactly this record as its per-symbol payload and add the relationship edges code2prompt lacks.
- **Per-file token counts rendered as a visual map** (`crates/code2prompt/src/token_map.rs`, `analysis.rs::TokenMapEntry`). Specera should surface "where did my context budget go" as a first-class output, per file and per directory. It makes budget behaviour debuggable instead of mysterious.
- **A library of named, task-specific prompt templates compiled into the product** (`builtin_templates.rs:29-60+`, `templates/*.hbs`). Specera has per-SDLC-stage prompts by definition; treat them as versioned, testable data files rather than string literals scattered through code.
- **Multiple tokenizer encodings behind an enum with a process-wide `OnceLock` cache** (`tokenizer.rs:26-39, 69-73`). Correct and cheap.
- **Feature-gating heavy grammar dependencies** (`Cargo.toml:19-23`) is the right *build* instinct — Specera should keep grammars loadable on demand rather than statically linking all of them.

### Avoid

- **Feature-gating the structural feature *off by default*** (`Cargo.toml:19-20`). Load grammars lazily at runtime; do not make the flagship capability a compile-time opt-in that most users never get.
- **Shipping no default ignore list** (`filter.rs`, `path.rs`). Trusting the user's `.gitignore` to protect secrets is not a policy.
- **`no_escape` on the template engine with no separate sanitisation pass** (`template.rs:35`). Specera needs a distinct trust boundary between "repo content" and "instructions", regardless of escaping.
- **Advertising a surface maintained in someone else's repo** (`README.md:36,84` vs `llms-install.md:22`). Specera's MCP server must be in-tree and versioned with the core.
- **A single-language test for a multi-language feature** (`entity_map.rs:113-120`). Specera needs a per-grammar fixture corpus, as `repomix` has (21 tree-sitter test files).

## 8. Build, borrow, buy, integrate, or reject

**Borrow** — narrowly. MIT (`LICENSE:3`) permits reuse, and three ideas are worth lifting: the file-type-aware schema-extraction processors, the `EntitySummary` record shape, and the per-file token-map visualisation. Do not integrate the tool: it cannot fetch a repo, has no index, no incremental update, no relationships, no secret handling, and no evaluation, so it solves none of Specera's structural problems. Its Rust core would be a language-boundary cost for capabilities Specera must build anyway. Note the `sem-core` transitive license is unresolved (§6) — settle that before copying `entity_map.rs` itself, as opposed to its record shape.

## 9. Evidence

- **HEAD read**: `ab4fa06` — `git -C .spike/clones/code2prompt rev-parse --short HEAD`
- **Last commit**: `ab4fa06 2026-06-18 Merge pull request #321 from rs545837/feat/sem-entity-map`; the feature commit is `1cab012 feat(core): entity-level code map via sem-core (#315)`.
- **History**: 679 commits total; first commit 2024-03-09; **73 commits in the last 6 months**.
- **Version**: `code2prompt-core` 4.3.0 (`crates/code2prompt-core/Cargo.toml:3`).
- **License**: MIT — `.spike/clones/code2prompt/LICENSE:3`, "Copyright (c) 2024 Mufeed VH". Verified by reading the file.
- **Files I read directly**: `crates/code2prompt-core/src/entity_map.rs:1-50` (module doc, `EntitySummary`, `FileCodeMap` — verified verbatim); `crates/code2prompt-core/Cargo.toml:15-35` (`default = []`, `entity-map = ["dep:sem-core"]`, `sem-core = { version = "0.13", optional = true }`, offline/no-telemetry comment — verified verbatim).
- **Paths cited from delegated static reading**: `crates/code2prompt-core/src/tokenizer.rs:6,26-39,54-65,69-73,85-108`; `filter.rs:70-76,139-152`; `path.rs:11,97-113`; `file_processor/mod.rs:1-5` and `{csv,tsv,jsonl,ipynb}.rs`; `template.rs:35,69-77,220-228`; `builtin_templates.rs:29-60+`; `templates/*.hbs`; `git.rs`; `selection.rs:38-39,63-69,171,238,259`; `session.rs:393-394,430-447`; `analysis.rs`; `sort.rs`; `entity_map.rs:52,59,76-83,104-107,113-120`; `crates/code2prompt/src/{main.rs,args.rs:24-26,tui.rs,token_map.rs,widgets/template/{editor,picker}.rs,Cargo.toml:55-57}`; `crates/code2prompt-python/src/python.rs`; `README.md:36,84`; `llms-install.md:1-91` (esp. `:22`).
- **Tests**: 15 test files / 3,740 lines under `crates/*/tests/`; heaviest are `crates/code2prompt-core/tests/filter_test.rs` (600+ lines of glob cases) and `path_test.rs`.
- **Negative results**: no secret scanning (`grep -rni 'secret|redact|credential'` over `crates/**/*.rs` → test fixtures only); no benchmark or Criterion harness (`grep -rni "benchmark|criterion"` → 0 hits outside `target/`); no MCP server code or dependency in `crates/`; no remote-fetch code.
- **Commands run**: `git rev-parse`, `git log`, `ls`, `sed -n`, `grep`, `find`, `wc -l`. **No `cargo build`, no test run, no code2prompt invocation.**
