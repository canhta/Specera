# DeepWiki-Open

A Next.js frontend + FastAPI backend that shallow-clones a repo, chunks every file by word count, embeds the chunks into a pickled FAISS index, and then asks an LLM — in two prompt calls composed **in browser JavaScript** — to invent a wiki table of contents from the file tree and README, and then to write each page from top-20 vector hits.

## 1. Verdict

Competitor in surface area, not in mechanism. It is the reference open implementation of the "point at a repo, get a wiki" gesture, and it is well distributed (10 README translations, Docker/Ollama/Bedrock/LiteLLM paths). Mechanically it is the purest example of the thing Specera must not be: **the wiki structure is one LLM call over a file tree string and a README, with no parse, no symbol table, and no check that the files it names exist.** Its own source comments admit the model cites files it was never given (`src/app/[owner]/[repo]/page.tsx:414-417`), and the fix applied is to turn those unverified citations into clickable GitHub URLs — increasing apparent authority without adding any verification. It has **zero** notion of a commit: nothing in `api/` references a SHA, the clone is never updated once it exists (`api/repository.py:339-345`), the FAISS pickle is reused whenever the file is present (`api/rag/pipeline.py:556-579`), and the wiki cache key is `{repo_type}_{owner}_{repo}_{language}` with no revision component (`api/services/wiki.py:31`). One genuine countercurrent: the new codemap feature does re-locate LLM citations in the real file — see §2 — but it fails open.

## 2. Core architecture and unique mechanism

**Two-phase generation, orchestrated client-side.** `FACT` The prompts that produce the wiki are string literals inside a 2,527-line React component, not backend code:

1. **Structure call** — `src/app/[owner]/[repo]/page.tsx:877-997`. Payload is exactly two things: a flat file-tree string in `<file_tree>` and the raw README in `<readme>`. No code is read. The model is told to "Create 8-12 pages" (comprehensive) or "4-6 pages" (concise) and return XML, and to nominate `<relevant_files>` per page. `FACT`
2. **Page call** — `page.tsx:576-688`, once per page, over WebSocket to `/ws/chat`. The backend answers via RAG (below). The prompt demands "at least 5 source files", `Sources: [path:start-end]()` citations, and "EXTENSIVELY use Mermaid diagrams". `FACT`

**Structure parsing is best-effort, twice over.** `page.tsx:1108-1207`: strip fences → regex for `<wiki_structure>…</wiki_structure>` → strip control chars → escape bare `&` → `DOMParser` as `text/xml` → **if the DOM yields zero pages, fall back to regexing `<page>…</page>` blocks out of the raw text** (`:1188-1208`). A parse error is logged and execution *continues* (`:1128-1137`, "We'll continue anyway since the XML might still be usable"). `FACT` There is no schema, no XSD, no rejection path.

**The nominated file paths are never checked to exist.** `page.tsx:1168-1172` pushes `<file_path>` text content straight into `page.filePaths`. `FACT` Those same strings are then (a) fed to the page-generation prompt as ground truth and (b) rebuilt by `postProcessWikiContent` into the canonical "Relevant source files" `<details>` block with each path linked via `generateFileUrl` → `{repoUrl}/blob/{branch}/{path}` (`:300-331, 369-387`). A hallucinated path becomes a confident link to a 404. `FACT`

**RAG.** `api/rag/pipeline.py` + `api/rag/rag.py`, built on adalflow. `read_all_documents` (`pipeline.py:151-284`) globs by extension only — 17 code extensions (`.py .js .ts .java .cpp .c .h .hpp .go .rs .jsx .tsx .html .css .php .swift .cs`) and 6 doc extensions, from `api/config/repo.json`. `FACT` No parser of any kind: no tree-sitter, no AST, no import resolution, no symbol extraction. Chunking is `split_by: "word", chunk_size: 350, chunk_overlap: 100` (`api/config/embedder.json`), embeddings default to `text-embedding-3-small` at **256 dimensions**, retriever `top_k: 20`. `FACT` The only structural signal is a boolean `is_implementation` computed by substring-matching `"test"` in the path (`pipeline.py:259-264`). `FACT`

**The one real grounding mechanism — codemap — and how it fails open.** `api/services/codemap.py`, added in HEAD commit `b5e7666`. `LineTrackingTextSplitter` (`pipeline.py:298-332`) annotates each chunk with true start/end lines by substring search, `_format_context` (`codemap.py:128-148`) presents them as `## File Path: <path>` + `[lines A-B]`, and the prompt (`api/prompts.py:208-214`) requires the `snippet` field be "copied VERBATIM… an exact substring". Then `_ground_citations` (`codemap.py:201-222`) **re-derives the line numbers from the real file**, with the docstring "LLM-provided line numbers are unreliable, but the snippet is copied verbatim, so the true location is recovered by searching the real file" (`:180-183`). This is the right instinct. Its three failure modes are all silent: `FACT`
- If the file cannot be opened (hallucinated path), the loop `continue`s and the LLM's invented `file_path` and line range survive into the output (`:214-218`).
- If the snippet is not found, `_locate_snippet` returns `None`, `if loc:` is false, and the LLM's guessed line numbers are kept (`:220-222`).
- `_locate_snippet` has a fallback that anchors on **only the first non-blank line** of the snippet (`:191-197`), so a snippet whose remainder was fabricated still gets "grounded" coordinates.

Nothing anywhere raises, flags, or records a grounding failure. There is no counter, no confidence field, no UI marker.

**Diagrams are unconstrained text.** The page prompt asks for Mermaid and lists arrow syntax at length (`page.tsx:607-641`); `src/components/Mermaid.tsx:384-395` catches render exceptions and shows "Syntax error in diagram". `FACT` That is the entire validation: *does it parse*. No edge in any generated diagram is ever compared to an import, a call, or a route.

**Persistence.** Wiki JSON at `~/.adalflow/wikicache/deepwiki_cache_{type}_{owner}_{repo}_{lang}.json` (`api/services/wiki.py:29-32`); FAISS/LocalDB pickle at `<repo_root>/databases/{name}.pkl` (`pipeline.py:287-291`); clone at `~/.adalflow/repos/{owner}_{repo}`.

## 3. Strongest capabilities

- **Snippet-anchored citation re-location** (`api/services/codemap.py:178-222` + `api/rag/pipeline.py:298-332`). Requiring a verbatim snippet and then recomputing its line range from disk is the single best idea in either repo I read. `FACT`
- **Broad model/provider matrix, config-driven.** `api/clients/` ships OpenRouter, Bedrock, Ollama, DashScope, LiteLLM, Anthropic, Google embedder; `api/config/generator.json` + `embedder.json` select them; separate `docker-compose-litellm.yml`, `Dockerfile-ollama-local`. Fully local operation is a supported path. `FACT`
- **Deterministic post-processing of model formatting drift** (`page.tsx:340-472`, five numbered repair passes: rebuild the sources block, resolve `[path:10-20]()`, resolve off-list paths, un-nest `[Sources: file.py:1-2]()`, strip stray `()`). It is treating the model as an unreliable emitter and normalising downstream — correct instinct, applied to formatting rather than truth. `FACT`
- **Multi-turn "Deep Research"** with distinct first/intermediate/final iteration prompts that force topic adherence across turns (`api/prompts.py:60-151`). `FACT`
- **Path-traversal guard on file reads**: `read_repo_file` resolves realpaths and compares `commonpath` before opening (`codemap.py:166-175`). `FACT`
- Genuinely maintained: 240 commits, 31 in the last six months, HEAD `b5e7666` dated 2026-07-30. `FACT` (coordinator-verified)

## 4. Critical weaknesses

- **No staleness concept anywhere.** `grep` over `api/` for `commit|sha|revision|HEAD` returns nothing relevant. `FACT` Three independent caches all key on repo identity, never revision: the clone (`repository.py:339-345` returns "Using existing repository" and **never fetches or pulls** — it is `git clone --depth=1 --single-branch`, so it is frozen at first clone forever), the FAISS pickle (`pipeline.py:556-579` returns the loaded docs unless *every* embedding is empty), and the wiki JSON (`services/wiki.py:29-32`). A wiki generated today is served unchanged after a year of commits, and the only invalidation is a human calling `DELETE /api/wiki_cache`.
- **The structure prompt never sees code.** `page.tsx:877-888` sends a file tree and a README. The architecture of the wiki is therefore an inference from *filenames*. Any project whose directory names mislead produces a misleading table of contents, and nothing downstream can correct it. `FACT`
- **Citations are decorated, not verified.** The comment at `page.tsx:414-417` states the problem in the authors' own words — "The model frequently cites additional files it read (e.g. `accelerator_connector.py`) that were never in the assigned list" — and the code that follows (`:421-434`) converts those into live `blob/{branch}/{path}` links. A citation to a file the model never received becomes indistinguishable from a real one. `FACT`
- **Codemap grounding fails open in all three failure modes** (§2). `FACT` A grounding step that cannot report failure provides assurance, not verification.
- **No parser, no graph, no cross-file edges.** Word-count chunks and 256-dim embeddings only. Nothing links a call to its definition; there is no import resolution, no route/queue/DI awareness, no cross-repo boundary handling. `FACT` (absence: no AST/tree-sitter dependency in `api/pyproject.toml`, no graph code under `api/`)
- **Quality is entirely unmeasured.** ~35 test functions total across `tests/` (`grep -c "def test"`), of which 15 are embedder plumbing and 5 are repo-name extraction. There is **no test of wiki structure generation, no test of `_ground_citations`, no test of `_locate_snippet`, and no accuracy benchmark or labelled dataset**. `FACT`
- **`POST /api/wiki_cache` is unauthenticated** (`api/routers/wiki.py:156-174`) while `DELETE` is gated behind `WIKI_AUTH_CODE` (`:193-196`). On any shared deployment, anyone who can reach the API can overwrite the cached wiki for any repo with arbitrary Markdown — which is then served to viewers as generated documentation. `FACT`
- **CORS is `allow_origins=["*"]` with `allow_credentials=True`** (`api/main.py:57-62`) on an API that accepts GitHub/GitLab/Bitbucket access tokens in request bodies. `FACT`
- **Access tokens are embedded in the clone URL** (`repository.py:350-401`) and passed to `git clone`, which persists the credential into `.git/config` inside `~/.adalflow/repos/…`. Only *error messages* are sanitised (`:417-426`); the on-disk remote URL is never rewritten. `FACT` (absence: no `git remote set-url` anywhere in `repository.py`)
- **Auth is a single shared string compared with `==`** (`api/routers/auth.py:18-22`). No users, no tenancy, no per-repo authorization. `FACT`
- **17 code extensions, hardcoded** (`api/config/repo.json`). No Kotlin, Scala, Ruby, Elixir, Terraform, SQL, or protobuf. Files over `MAX_EMBEDDING_TOKENS * 10` (81,920 tokens) are silently skipped (`pipeline.py:250-254`) — the largest, usually most important, files vanish with only a log line. `FACT`
- **Prompt construction lives in the browser**, so every prompt is user-editable and the backend has no canonical notion of what a "wiki page" request is. `FACT` (`page.tsx:576, 877`)

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements / PRD | No | Nothing. Generation input is a file tree and a README. |
| Jira / work tracking | No | No tracker code in `api/` or `src/`. |
| Architecture / ADR | Partial | Generates an "System Architecture" wiki section and Mermaid diagrams (`page.tsx:911-921, 607-641`) — descriptive, unverified, undated, no decision record, no alternatives, no supersession. |
| Implementation | No | Writes no code, applies no edits. |
| PR review | No | No diff awareness; the clone is `--depth=1` so there is no history to diff against (`repository.py:409`). |
| Test generation | No | Nothing. |
| Security / pentest | No | Nothing — and see §4 for its own posture. |
| Release | No | Nothing. |
| Monitoring / incidents | No | Nothing. |
| Maintenance / knowledge | Partial | This is the whole product: a browsable wiki, a repo Q&A chat (`api/routers/chat.py`), Deep Research (`api/services/research.py`), and codemap guided tours (`api/services/codemap.py`). Undermined by having no revision binding at all. |

## 6. Security, deployment, and license

- **Deployment**: Docker Compose (`docker-compose.yml`), plus LiteLLM and local-Ollama variants; Next.js on 3000, FastAPI on 8001 (`api/main.py`). Self-host only in this repo. The maintainer additionally operates a hosted successor, "Grok Wiki" at `grok-wiki.com`, promoted from `README.md:21-23` (commit `56669d8`, 2026-05-21, "Grok Wiki is now Live!"). `FACT` The hosted product's architecture is `UNVERIFIED` — would require reading its terms/docs, out of scope here.
- **Auth/tenancy**: one optional global code (`api/routers/auth.py`), gating only wiki deletion. No accounts, no per-repo ACL. Anything the server has cloned, any caller can read via `GET /api/wiki_cache` and `/local_repo/structure`. `FACT`
- **Secrets**: user-supplied VCS PATs travel in JSON request bodies to `/ws/chat` and `/chat/stream`, are interpolated into clone URLs, and land in `.git/config` on the server's disk. Provider API keys come from `.env`. There is **no secret scanning of repo content before it is embedded or sent to the model** — contrast `repomix`, which does exactly this by default. `FACT` (absence: no secretlint/detect-secrets/regex scan under `api/`)
- **Network egress**: shallow clone from the VCS host, plus embedding and completion calls to whichever of OpenAI/Google/OpenRouter/Bedrock/DashScope/Anthropic/LiteLLM/Ollama is configured. Every file that survives the extension filter is embedded and eligible to be sent to the model. `FACT`
- **Prompt-injection surface: severe and structural.** Repo content is the payload of every call, and the entire prompt is assembled in the browser from unsanitised repository text — the file tree (attacker-controlled filenames), the README (attacker-controlled prose), and retrieved chunks. A README containing wiki-structure instructions or a fake `<wiki_structure>` block directly steers the structure call, whose output is then parsed by a **regex fallback that accepts `<page>` blocks from anywhere in the response** (`page.tsx:1188-1208`). `FACT` No sanitisation, no delimiter escaping, no instruction/data separation exists.
- **License**: MIT — `.spike/clones/deepwiki-open/LICENSE:1-3`, "Copyright (c) 2024 Sheing Ng". `FACT` (verified by reading the file) Fully permissive; anything here can be vendored.
- **Naming / trademark friction**: the repo is `AsyncFuncAI/deepwiki-open` and the README opens "**DeepWiki** is my own implementation attempt of DeepWiki" (`README.md:5`), i.e. it names itself after Cognition's hosted DeepWiki product (covered in `competitors/services/deepwiki-devin.md`). The cache filename prefix `deepwiki_cache_` is baked into the on-disk format and the project-listing parser (`api/services/wiki.py:31, 104`). The project has since rebranded its hosted successor to "Grok-Wiki" (`README.md:1`, commit `56669d8`) while keeping the `deepwiki-open` repo name — a rename away from the borrowed mark that did not propagate to the code. `INFERENCE` from those two facts; no trademark action is documented in the repo and I did not verify one. `UNVERIFIED` — checking Cognition's trademark filings or any takedown correspondence would settle it.
- **Imitation, not reverse engineering.** `FACT` The implementation is a straightforward RAG-over-chunks design with prompts written in the repo's own voice. There is no captured API schema, no scraped output format, no mimicry of an internal representation — nothing that indicates access to the hosted product's internals. It copies the *product gesture* (repo URL in, sectioned wiki with Mermaid diagrams and file citations out), which is why the README calls itself "my own implementation attempt".

## 7. Ideas to adopt or avoid

### Adopt

- **Verbatim-snippet citations, with the line range recomputed from disk.** `api/services/codemap.py:178-222`. Specera should require every generated claim to carry an exact source substring and then locate it in the indexed blob. Take the mechanism; invert the failure behaviour — see Avoid.
- **Line-range-annotated chunks in the context window.** `LineTrackingTextSplitter` (`api/rag/pipeline.py:298-332`) gives each chunk a true `start_line`/`end_line`, and `_format_context` (`codemap.py:128-148`) groups chunks under a `## File Path:` header with `[lines A-B]` markers. This is what makes a citation checkable at all; Specera's retrieval layer should emit the same envelope, with a blob SHA added.
- **Skeleton-then-enrich two-call split.** `codemap.py:265-303`: call one produces structure + citations only, call two fills prose and diagrams and is explicitly forbidden to add or remove steps (`api/prompts.py:258-259`). Enrichment failure is non-fatal and degrades to the skeleton (`:299-303`). Specera should structure generation the same way, so the *verifiable* artifact (the citation set) is produced independently of the *unverifiable* one (the prose) and can be validated before enrichment runs.
- **Deterministic post-processing of model formatting drift.** `page.tsx:340-472`. Do not prompt-engineer output shape; emit it programmatically from data you hold. In particular, build the "sources" block from your own list — never from the model's.

### Avoid

- **Grounding checks that fail open.** `codemap.py:214-222` keeps the LLM's invented coordinates when verification fails. Specera must reject or visibly quarantine the claim, count grounding failures per artifact, and surface that count. A verification step with no failure path is worse than none, because it manufactures trust.
- **Anchoring on the snippet's first line as a fallback** (`codemap.py:191-197`). Partial matches must be failures, not successes.
- **Turning unverified citations into live links** (`page.tsx:414-434`). If a cited path is not in the indexed file set, render it as an unresolved claim, not a `blob/` URL.
- **Deriving structure from filenames and README prose** (`page.tsx:877-888`). Specera's document skeleton must come from parsed structure — modules, entry points, dependency edges — not from a directory listing.
- **Caching a generated artifact under a key with no revision component** (`services/wiki.py:31`). Every Specera artifact must be keyed by content/commit and carry the SHA it was derived from, so "is this stale?" is a comparison, not a guess.
- **Reusing a clone without fetching** (`repository.py:339-345`). Silent permanent staleness at the source.
- **A regex fallback that scavenges structure out of malformed model output** (`page.tsx:1188-1208`). Prefer schema-constrained decoding and a hard retry; salvaging a bad parse is how a prompt injection in a README becomes wiki structure.
- **Assembling prompts in the browser** (`page.tsx:576, 877`). Prompts are part of the trusted computing base.
- **`allow_origins=["*"]` + `allow_credentials=True`** (`api/main.py:57-62`) and an unauthenticated cache-write endpoint (`routers/wiki.py:156`).

## 8. Build, borrow, buy, integrate, or reject

**Reject as a system; borrow two mechanisms.** MIT (`LICENSE:1`) imposes no constraint, so `LineTrackingTextSplitter` (`api/rag/pipeline.py:298-332`) and the snippet-relocation logic in `_ground_citations`/`_locate_snippet` (`api/services/codemap.py:178-222`) can be lifted directly — they are ~80 lines and encode the correct idea. Everything above them is the architecture Specera exists to replace: no parser, no graph, no revision binding, no verification with a failure path, no evaluation. Its value to this spike is as the crisp negative example — including the authors' own comment at `page.tsx:414-417` documenting hallucinated citations and choosing to hyperlink them.

## 9. Evidence

- **HEAD read**: `b5e7666` — last commit 2026-07-30 "Feat/codemap pr (#565)"; 240 commits total, 31 in the last six months. (coordinator-verified)
- **License**: MIT, `.spike/clones/deepwiki-open/LICENSE:1-3`, "Copyright (c) 2024 Sheing Ng". Verified by reading the file.
- **Files read in full**: `api/services/wiki.py`, `api/rag/pipeline.py`, `api/prompts.py`, `api/services/codemap.py`, `api/routers/auth.py`.
- **Files read in part**: `src/app/[owner]/[repo]/page.tsx` (lines 300-472, 560-720, 860-1010, 1146-1240, 1370-1400 of 2,527), `api/repository.py:328-450`, `api/routers/wiki.py:125-200`, `api/main.py:55-63`, `api/rag/rag.py` (symbol listing), `src/components/Mermaid.tsx` (error-handling grep), `README.md:1-40`.
- **Config read**: `api/config/embedder.json` (full — `top_k: 20`, `chunk_size: 350`, `chunk_overlap: 100`, `text-embedding-3-small` @ 256 dims), `api/config/repo.json` (extension lists).
- **Negative results (searches that returned nothing)**:
  - `grep -rn "commit|sha|revision|HEAD" api/*.py api/*/*.py` → no revision tracking; only unrelated hits (`route.methods - {"HEAD"}`, numpy `.shape`).
  - `grep -rn "set-url|remote\b" api/repository.py` → empty; the tokenised clone URL is never rewritten.
  - No tree-sitter / AST / graph dependency or module anywhere under `api/`.
  - No secret-scanning of repo content anywhere under `api/`.
  - No accuracy benchmark, eval harness, or labelled dataset in the repo.
- **Test census**: `grep -c "def test" tests/**/*.py` → 35 test functions total; `tests/unit/test_all_embedders.py` 15, `tests/test_extract_repo_name.py` 5, `tests/unit/test_google_embedder.py` 3, `tests/unit/test_chat.py` 3, `tests/integration/test_full_integration.py` 3, remainder 1-2 each. Zero cover wiki generation, citation grounding, or diagram output.
- **Commands run**: `git log`, `git rev-parse`, `find`, `wc -l`, `ls`, `grep`, `sed -n`, `head`, and one `python3 -c` that only `json.load`ed `api/config/repo.json`. **No install, build, dev server, Docker, or test suite was executed.**
