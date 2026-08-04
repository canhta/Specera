# Competitor index

One file per competitor. Details live only in the competitor's own file; every
other document links here rather than repeating. Acquisition metadata, commit
hashes, and licenses are in [`../inventory.md`](../inventory.md). Cross-cutting
analysis is in [`../comparison.md`](../comparison.md).

## Open source — code-graph engines

| File | What it is |
|---|---|
| [graphify](graphify.md) | Code graph builder; OSS counterpart to [Graphify Platform](services/graphify-platform.md) |
| [gitnexus](gitnexus.md) | Code graph + agent skill/hook suite; PolyForm Noncommercial |
| [potpie](potpie.md) | Agent platform over a code graph |
| [codegraph](codegraph.md) | Code graph indexer |
| [codegraphcontext](codegraphcontext.md) | Code graph as MCP context server |
| [stakgraph](stakgraph.md) | Multi-language AST/LSP graph; no license file |

## Open source — search and retrieval

| File | What it is |
|---|---|
| [serena](serena.md) | LSP-driven symbolic code tools over MCP |
| [grepai](grepai.md) | Semantic grep |
| [claude-context](claude-context.md) | Embedding-based code retrieval (Zilliz/Milvus) |
| [sourcebot](sourcebot.md) | Self-hosted code search UI over zoekt; FSL licensed |
| [zoekt](zoekt.md) | Trigram-index code search engine (Sourcegraph upstream) |
| [opengrok](opengrok.md) | Lucene-based source cross-reference and search (Oracle) |
| [bloop](bloop.md) | Rust semantic code search + LLM; dormant since 2024-12 |

## Open source — context packing, agents, comprehension

| File | What it is |
|---|---|
| [aider](aider.md) | Autonomous coding agent with repo-map and benchmark harness |
| [repomix](repomix.md) | Repo → single LLM-ingestible artifact |
| [gitingest](gitingest.md) | Repo → text digest; dormant since 2025-08 |
| [code2prompt](code2prompt.md) | Repo → prompt with templating |
| [deepwiki-open](deepwiki-open.md) | LLM-generated repo wiki |
| [gitdiagram](gitdiagram.md) | LLM-generated architecture diagram |

## Commercial and closed

| File | Why it matters |
|---|---|
| [Graphify Platform](services/graphify-platform.md) | Commercial layer over graphify |
| [GitNexus Enterprise](services/gitnexus-enterprise.md) | Commercial layer over GitNexus |
| [Sourcegraph](services/sourcegraph.md) | Incumbent code intelligence; upstream of zoekt |
| [Augment Code](services/augment-code.md) | Retrieval-centric coding assistant |
| [Greptile](services/greptile.md) | Graph-backed PR review |
| [CodeRabbit](services/coderabbit.md) | PR review at scale |
| [DeepWiki / Devin](services/deepwiki-devin.md) | Repo comprehension + autonomous engineer |
| [GitHub Copilot](services/github-copilot.md) | Owns code, PR, and release systems of record |
| [GitLab Duo](services/gitlab-duo.md) | Owns the entire chain in one product |
| [Atlassian Rovo](services/atlassian-rovo.md) | Owns Jira and Confluence — the requirement source of truth |

## Report format

Every file carries exactly nine sections: Verdict · Core architecture and unique
mechanism · Strongest capabilities · Critical weaknesses · SDLC coverage ·
Security, deployment, and license · Ideas to adopt or avoid · Build/borrow/buy/
integrate/reject · Evidence.

Claims are labelled `FACT`, `INFERENCE`, `VENDOR CLAIM`, or `UNVERIFIED`. `FACT`
requires a path, commit hash, or documentation URL.
