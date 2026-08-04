# Serena

An MCP server that proxies 70 Language Server Protocol implementations (plus an optional JetBrains-plugin backend) into ~51 symbol-level tools for coding agents; it has no search index of its own, only a per-file document-symbol cache.

## 1. Verdict

`INFERENCE` (rests on the facts in §2–§4): Serena is a **component**, not a competitor. It is the only project in this group that gets symbol resolution from real compilers/type-checkers rather than from an approximation (trigrams, tree-sitter, or embeddings), which means its `find_referencing_symbols` and `rename_symbol` results are as correct as `rust-analyzer`/`gopls`/`jdtls` are — no hallucination surface and no recall guessing. `FACT`: it is MIT-licensed (`LICENSE:1`), extremely active (1,135 commits in the last 6 months, HEAD `cd04838b` dated 2026-08-03), and already speaks MCP, so Specera could mount it as the symbol layer with near-zero integration risk. What limits it: it holds **no cross-file index** — every reference query is a live LSP round-trip, and cross-file correctness depends on a hardcoded `sleep(2)` waiting for the language server to finish its own indexing (`src/solidlsp/ls.py:1041`, `:1627`). It answers "where is this symbol used" excellently and answers "which code is about billing retries" not at all.

## 2. Core architecture and unique mechanism

`FACT` — **Two interchangeable backends.** The default is `solidlsp`, a from-scratch LSP client (`src/solidlsp/ls.py`, 3,256 lines) that launches a language server as a stdio subprocess (`src/solidlsp/ls_process.py`) and drives it with `textDocument/documentSymbol`, `textDocument/references`, `textDocument/definition`, `textDocument/implementation`, `textDocument/rename`, and `textDocument/publishDiagnostics`. The second backend is an HTTP client to a JetBrains IDE plugin (`src/serena/jetbrains/jetbrains_plugin_client.py`, bound to `127.0.0.1` per `src/serena/config/serena_config.py:885`), which supplies refactorings the LSP does not expose (move, safe-delete, inspections).

`FACT` — **70 language server adapters** live in `src/solidlsp/language_servers/*.py` (count from `ls src/solidlsp/language_servers/*.py | wc -l` = 70), each a subclass that knows how to install/locate its server binary and how to build launch args: `gopls.py`, `rust_analyzer.py`, `eclipse_jdtls.py`, `pyright_server.py`/`basedpyright_server.py`/`jedi_server.py`/`ty_server.py`/`pyrefly_server.py` (five Python options), `typescript_language_server.py`, `clangd_language_server.py`, `intelephense.py`, `solargraph.py`/`ruby_lsp.py`, `sourcekit_lsp.py`, plus long-tail ones (Ada, AL, BSL, Crystal, Haxe, Lean4, MATLAB, Pascal, SystemVerilog, Godot).

`FACT` — **There is no index; there is a per-file symbol cache.** `src/solidlsp/ls.py:555` and `:560` declare two dicts mapping *relative file path → (file_content_hash, symbols)*: `_raw_document_symbols_cache` (the raw LSP response) and `_document_symbols_cache` (Serena's normalised `DocumentSymbols`). The key is an MD5 of file contents (`src/solidlsp/ls.py:212-216`). These are pickled to `<project>/.serena/cache/<language_id>/` (`src/solidlsp/ls.py:348-357`, `:550`). Nothing cross-file is stored — no reference edges, no call graph, no inverted index.

`FACT` — **Query path for "who calls X"** is `request_referencing_symbols` (`src/solidlsp/ls.py:2367`): it calls `request_references` (a live LSP request) and then, for *every* returned reference location, opens the containing file and runs `request_containing_symbol` to map the raw location back to an enclosing symbol. Cost is therefore O(number of references) LSP/file operations at query time, not amortised into an index.

`FACT` — **Tool surface**: 51 classes deriving from `Tool` across `src/serena/tools/` (`grep -h "^class .*Tool(" src/serena/tools/*.py | wc -l` = 51). Symbolic ones (`src/serena/tools/symbol_tools.py`): `GetSymbolsOverviewTool`, `FindSymbolTool`, `FindReferencingSymbolsTool`, `FindImplementationsTool`, `FindDeclarationTool`, `GetDiagnosticsForFileTool`, `GetDiagnosticsForSymbolTool`, `ReplaceSymbolBodyTool`, `InsertAfterSymbolTool`, `InsertBeforeSymbolTool`, `RenameSymbolTool`, `RestartLanguageServerTool`. Plus file/regex tools (`file_tools.py`), a markdown "memories" store (`memory_tools.py`), and `ExecuteShellCommandTool` (`src/serena/tools/cmd_tools.py:11`).

`FACT` — **Warm-up path**: `serena project index` (`src/serena/cli.py:791-844`) walks `proj.gather_source_files()`, calls `ls.request_document_symbols(f)` on each file with a default 10-second per-file timeout, flushes the pickle cache every 30 seconds, and writes failures to `.serena/logs/indexing.txt`. Failures are logged and skipped, not retried.

## 3. Strongest capabilities

- `FACT` Symbol resolution is delegated to the actual language toolchain, so results are compiler-grade rather than heuristic. Evidence: `src/solidlsp/ls.py:1712` `request_references` is a thin wrapper over the LSP `textDocument/references` request; there is no local resolver to be wrong.
- `FACT` Breadth no other tool in this group matches: 70 language server adapters (`src/solidlsp/language_servers/`), against zoekt/OpenGrok/bloop's tokenizer-level language lists.
- `FACT` Symbol-level *editing*, not just reading: `ReplaceSymbolBodyTool`, `InsertAfterSymbolTool`, `RenameSymbolTool` (`src/serena/tools/symbol_tools.py:585,618,670`) let an agent edit by symbol name instead of line numbers — this eliminates the whole class of stale-line-number edit failures.
- `FACT` Per-language behavioural test suites exist: 178 `test_*.py` files, with per-language symbol-retrieval directories under `test/solidlsp/` for ~60 languages (`test/solidlsp/{ada,al,angular,bash,clojure,cpp,crystal,csharp,dart,elixir,erlang,fortran,fsharp,go,groovy,haskell,haxe,java,julia,kotlin,lean4,lua,matlab,nix,ocaml,pascal,perl,php,powershell,ruby,rust,...}`). This is real coverage of the core, unlike most repos in this group.
- `FACT` Cache invalidation is content-addressed, not timestamp-based (`src/solidlsp/ls.py:1947-1956` compares `file_hash == file_data.content_hash`), so a `git checkout` that restores identical content does not force re-parsing.

## 4. Critical weaknesses

- `FACT` **Cross-file correctness depends on a sleep.** `_get_wait_time_for_cross_file_referencing()` returns a hardcoded `2` seconds (`src/solidlsp/ls.py:1041-1046`), and its own docstring admits: *"LS may return incomplete results on calls to `request_references` (only references found in the same file), if the LS is not fully initialized yet."* `_wait_for_cross_file_references_if_needed` (`:1627-1632`) sleeps once per session. `INFERENCE` (from that docstring + the fact that jdtls/rust-analyzer indexing on a large repo takes far longer than 2s): on a large monorepo the first reference query can silently return same-file-only results with no error. Several servers override the constant (`vue_language_server.py:851`, `angular_language_server.py:602`, `haxe_language_server.py:407`, `fsharp_language_server.py:430`), which confirms 2s is empirically wrong often enough to need per-language tuning.
- `FACT` **Reference lookup does not scale down to a cheap operation.** `request_referencing_symbols` (`src/solidlsp/ls.py:2400-2420`) loops over every reference and opens the containing file. A symbol with thousands of references costs thousands of file opens per query.
- `FACT` **A documented correctness hack in the core.** `src/solidlsp/ls.py:2424-2426` contains, verbatim: `# TODO: HORRIBLE HACK! I don't know how to do it better for now...` / `# THIS IS BOUND TO BREAK IN MANY CASES! IT IS ALSO SPECIFIC TO PYTHON!` — a Python-specific fallback in a language-agnostic code path.
- `FACT` **No retrieval-quality measurement whatsoever.** The only evaluation material (`docs/04-evaluation/000_evaluation-intro.md`) is an *agent self-report*: "The agent evaluates itself. This is deliberate" (`docs/04-evaluation/000_evaluation-intro.md:31`). There is no precision, recall, MRR, or ground-truth reference set anywhere in the repo. All headline claims in the README are LLM-generated testimonials.
- `FACT` **Evaluation results are not from the default backend.** `docs/04-evaluation/030_results/000_evaluation-results.md:9-11`: *"All evaluations were conducted using the JetBrains-powered version of Serena, as it is the more powerful backend."* The LSP backend — the one nearly every user runs — was not evaluated. `VENDOR CLAIM`: that it can "easily be repeated with the LSP-based backend."
- `FACT` **Cross-repository/service edges do not exist.** Scope is a single `repository_root_path` plus explicitly configured extra workspace folders (`src/solidlsp/ls.py:587-593`). There is no concept of a service boundary, an HTTP call between services, a queue topic, or DI/config-driven wiring — anything the language server cannot resolve statically is simply absent.
- `FACT` **Language-server lifecycle is a liability.** A `RestartLanguageServerTool` (`src/serena/tools/symbol_tools.py:25`) is shipped as a user-facing MCP tool — the design assumes the LSP subprocess will wedge and that the *agent* should recover it.
- `FACT` **Requires a working toolchain per language.** `src/solidlsp/language_servers/gopls.py:93` errors with "Go is not installed…" — Serena degrades to zero symbolic capability if the target language's compiler is absent from the host, which is common in a CI/container context.

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements/PRD | No | No tool touches requirements; closest is a freeform markdown memory store (`src/serena/tools/memory_tools.py`) |
| Jira/work tracking | No | No issue-tracker integration anywhere in `src/serena/` |
| Architecture/ADR | No | `GetSymbolsOverviewTool` (`symbol_tools.py:36`) returns file-level symbol lists, not architecture |
| Implementation | Yes | `ReplaceSymbolBodyTool`, `InsertAfterSymbolTool`, `RenameSymbolTool`, `ReplaceInFilesTool` (`symbol_tools.py:585,618,670`; `file_tools.py:232`) |
| PR review | No | No git/diff/PR tool in `src/serena/tools/`; `ExecuteShellCommandTool` could shell out to `git` but nothing is modelled |
| Test generation | No | No test-authoring tool; `GetDiagnosticsForFileTool` (`symbol_tools.py:482`) surfaces compiler diagnostics only |
| Security/pentest | No | Nothing in `src/serena/tools/` |
| Release | No | Nothing in `src/serena/tools/` |
| Monitoring/incidents | No | Nothing in `src/serena/tools/` |
| Maintenance/knowledge | Partial | `WriteMemoryTool`/`ReadMemoryTool`/`EditMemoryTool` (`memory_tools.py:9,38,94`) persist markdown notes in `.serena/memories/`; unstructured, unversioned against code, no staleness detection |

## 6. Security, deployment, and license

`FACT` **License: MIT** (`LICENSE:1`, "Copyright (c) 2025 Oraios AI"). Fully permissive — Specera can vendor, fork, or link `solidlsp` with attribution only. This is the most reuse-friendly license in this competitor group.

`FACT` **Deployment**: local process only. Runs as an MCP server over stdio or SSE; the optional web dashboard defaults to `web_dashboard_listen_address = "127.0.0.1"` with `web_dashboard_trusted_hosts = ["127.0.0.1", "localhost"]` (`src/serena/config/serena_config.py:883-884`), and the JetBrains bridge to `127.0.0.1` (`:885`). No SaaS, no tenancy model, no auth — it is single-user by construction.

`FACT` **Prompt-injection surface is severe and by design.** `ExecuteShellCommandTool` (`src/serena/tools/cmd_tools.py:11`) executes arbitrary shell strings supplied by the LLM, with the only guard being a docstring instruction to the model: *"Never execute unsafe shell commands!"* (`cmd_tools.py:27`). `INFERENCE`: since Serena also feeds repository file contents back into the model, any attacker-controlled string in a dependency, a README, or a code comment reaches a model that holds an unrestricted shell tool. Specera must not adopt this pattern; if Serena is mounted, that tool must be disabled at the tool-registration layer.

`FACT` **Network egress**: Serena itself makes no model calls (the client LLM does). Egress comes from language-server bootstrap — adapters download or shell out to install server binaries (e.g. `rust_analyzer.py:172` points at GitHub releases). `INFERENCE`: in an air-gapped or locked-down deployment, language servers must be pre-baked into the image.

`FACT` **Secrets**: no credential handling in the codebase; the `.serena/` directory (caches, memories, logs) is written inside the user's repository, so `.serena/memories/*.md` can leak into commits if not gitignored.

## 7. Ideas to adopt or avoid

### Adopt

- **Content-hash-keyed symbol cache.** Key every cached parse by MD5 of file contents rather than mtime (`src/solidlsp/ls.py:212-216`, `:1947-1956`). Specera should do the same so that branch switches, rebases, and `git stash` cycles do not invalidate work that is byte-identical.
- **Symbol-addressed edits as the write primitive.** `ReplaceSymbolBodyTool` / `InsertAfterSymbolTool` (`symbol_tools.py:585,618`) address code by `name_path` (e.g. `MyClass/my_method`) instead of line ranges. Specera's implementation stage should expose the same primitive so a plan written at PRD time survives unrelated edits to the file.
- **Mount `solidlsp` as the ground-truth symbol resolver.** It is MIT, importable as a Python package independent of the MCP layer, and gives 70 languages for free. Specera would call it for definition/reference/rename and *never* re-implement those with tree-sitter.
- **Per-language conformance test directories.** `test/solidlsp/<lang>/test_*_symbol_retrieval.py` gives one behavioural suite per language against a fixture repo. Specera should copy this shape for its own parser/graph layer — it is the only credible way to keep 20+ languages from silently rotting.

### Avoid

- **The `sleep(2)` readiness heuristic** (`src/solidlsp/ls.py:1041-1046`). Specera must gate on an actual readiness signal (server-specific progress notifications, or a probe query with a known-nonlocal answer) and must fail loudly rather than return same-file-only references.
- **An unrestricted shell tool in the same session as repository content** (`cmd_tools.py:11`).
- **Agent-self-report as an evaluation method** (`docs/04-evaluation/000_evaluation-intro.md:31`). It produces quotable sentences and zero comparable numbers. Specera needs a fixed ground-truth retrieval set with precision/recall, which no repo in this group has.
- **Query-time O(references) file reopening** (`ls.py:2400-2420`). Materialise reference edges into a store instead.

## 8. Build, borrow, buy, integrate, or reject

**INTEGRATE (as a library, not as an MCP peer).** MIT (`LICENSE:1`) imposes no constraint beyond attribution, so Specera can vendor `src/solidlsp/` directly and skip the `src/serena/` MCP/agent/shell layer entirely — that layer contributes the prompt-injection surface (`cmd_tools.py:11`) and the memory store, neither of which Specera wants. `INFERENCE`: the right shape is Specera calling `SolidLanguageServer` in-process for definition/reference/rename ground truth, wrapping it with its own readiness gate to fix the `sleep(2)` defect, and persisting reference edges into Specera's own store so queries are not O(references) LSP calls. Serena remains a competitor only for the narrow "agent navigates code" use case, which is one stage of Specera's eleven.

## 9. Evidence

- Commit read: `cd04838b` — `git -C .spike/clones/serena rev-parse --short HEAD`
- Last commit: `cd04838b 2026-08-03 Merge pull request #1804 from oraios/ls-notify-on-reopen-changed`
- History: 3,223 commits total; 1,984 in the last 12 months; 1,135 in the last 6 months; first commit `e93169bc 2025-03-23`. Very actively maintained.
- License: `LICENSE:1` — MIT, Oraios AI.
- Key files read: `src/solidlsp/ls.py` (3,256 lines — cache model, reference resolution, readiness wait), `src/solidlsp/ls_config.py`, `src/serena/cli.py:749-884` (indexing commands), `src/serena/tools/symbol_tools.py`, `src/serena/tools/cmd_tools.py`, `src/serena/tools/memory_tools.py`, `src/serena/config/serena_config.py:880-890`, `src/serena/jetbrains/jetbrains_plugin_client.py`, `README.md`, `docs/04-evaluation/000_evaluation-intro.md`, `docs/04-evaluation/030_results/000_evaluation-results.md`.
- Commands run (all read-only): `git rev-parse`, `git log`, `ls`, `grep`, `sed -n` for file ranges, `wc -l`. No build, install, or test suite was executed.
- Counts derived: `ls src/solidlsp/language_servers/*.py | wc -l` → 70; `grep -h "^class .*Tool(" src/serena/tools/*.py | wc -l` → 51; `find test -name 'test_*.py' | wc -l` → 178.
- `UNVERIFIED`: actual first-query latency and reference completeness on a >1M-LOC monorepo. Verifiable by running `serena project index` against a large repo and comparing `find_referencing_symbols` output before and after the language server reports indexing complete.
