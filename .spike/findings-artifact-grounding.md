# Raw evidence: what "grounded output" actually means today

Coordinator note, 2026-08-04. **Input for the design wave** — supersedes an
earlier, sloppier coordinator hypothesis. Not a deliverable.

## The hypothesis that was wrong

The coordinator briefed R3b with this `INFERENCE`: *"nobody in this competitor
set produces documentation that is provably in sync with code, so verifiable
documentation is a candidate differentiator."*

R3b tested it against source and **partially refuted it**. GitDiagram does real
grounding, and stating the differentiator as "we validate" would put Specera in a
race it has already lost:

- The model never emits renderable syntax. It returns a **Zod-schema-constrained
  AST** (`gitdiagram/.../openai.ts:382-388`); a deterministic compiler produces
  the Mermaid with total entity-escaping (`graph.ts:211-236`, `:379-473`).
- Every claimed file path is checked with `Set.has` against the authoritative
  git tree, with typed failure categories that are counted, persisted, and shown
  to the user per attempt, plus a bounded feedback-retry loop.
- No loose-parse fallback.

`deepwiki-open` attempts something similar — verbatim-snippet citations whose
line ranges are recomputed from disk (`api/services/codemap.py:178-222`,
`api/rag/pipeline.py:298-332`) — and fails open in three silent ways.

## The gap that is real, and is sharper

Two things that **no tool in this competitor set does**:

**1. Nobody verifies edges — only that named entities exist.**
Both tools confirm the *nodes* are real and reject the ones that are not. Neither
verifies that any asserted *relationship* is real, because neither reads source
for that purpose: GitDiagram's `getGithubData` fetches only the tree and README —
**no file contents, ever** (`github.ts:406`) — and its edge validation checks only
that both endpoints are known node ids (`graph.ts:144-163`). Every arrow in a
GitDiagram architecture diagram is model invention over a filename list.
deepwiki-open embeds text chunks, so its relationships are likewise unparsed.

**2. Nobody binds an artifact to a commit.**
Neither tool puts a revision in any cache key. `deepwiki-open`'s wiki key is
`{type}_{owner}_{repo}_{lang}` with no SHA (`api/services/wiki.py:31`); its clone
is `--depth=1` and is **never fetched or pulled again once it exists**
(`api/repository.py:339-345`); the FAISS index is reused whenever present
(`api/rag/pipeline.py:556-579`). A grep of `api/` for `commit|sha|revision`
returns nothing relevant. GitDiagram's `cache-key.ts:50` omits the SHA even
though the tree SHA is present in a response it already fetches. Freshness is a
wall-clock timestamp at best, and there is no regeneration trigger anywhere.

Corroborating detail worth citing: deepwiki-open's own authors documented, in a
code comment at `src/app/[owner]/[repo]/page.tsx:414-417`, that the model cites
files it was never given — and the code immediately following converts those
hallucinated paths into live GitHub `blob/` links.

## How the differentiator must be stated

Not *"Specera validates its output"* — GitDiagram already validates, with a
tighter mechanism than a hand-rolled one would be.

**"Edges derived from parsed code, and every artifact keyed by the commit it
describes."**

Both halves are load-bearing and both are currently unoccupied. The second half
is also what makes staleness *detectable* rather than merely asserted: an
artifact whose key is a SHA is automatically invalid when the SHA moves, with no
heuristic required.

## Mechanisms to adopt regardless of which concept wins

- **Schema-constrained generation with no loose-parse fallback**, then a
  deterministic compiler to the target grammar (from GitDiagram). Apply to every
  Specera artifact that has a grammar — Gherkin, ADRs, runbooks, release notes.
- **Verbatim-substring citation**: require the model to emit an exact source
  substring, then locate it on disk to compute the line range, rather than
  trusting model-emitted line numbers (from deepwiki-open's codemap, which has
  the right idea and the wrong failure mode).
- **Typed, counted, user-visible failure categories per generation attempt**
  (from GitDiagram) — this is the honest alternative to a confidence score.
