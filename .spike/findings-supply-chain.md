# Raw evidence: agent-directive supply chain surface in competitor repos

Collected by the coordinator on 2026-08-04, first-hand, during clone setup.
**Input for the security red team (`docs/spike/security.md`) — not itself a
deliverable.** Do not copy this file into `docs/`; cite and interpret it there.

## What happened

Cloning 19 competitor repositories into `.spike/clones/` caused the coordinating
agent's harness to surface **three skills from `repomix/.claude/skills/`**
(`agent-carnet`, `contextual-commit`, `repomix-explorer`) as directory-scoped
invocable capabilities in its own available-skills list. No file from a
competitor repo was read, approved, or trusted at that point — the act of
placing the repos on disk was sufficient.

`FACT` — This was observed directly in this session. The skills appeared in a
system-reminder listing after the clone completed.

`FACT` — None of the hooks or MCP servers below executed in this session. They
are packaged as templates/plugins requiring installation, and project MCP servers
require approval. The exposure demonstrated was the skill listing only.

## Scope of the surface

`FACT` — 10 of 19 cloned repos ship agent-directive files. Counts of matching
files per repo (`CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.claude/**`,
`.mcp.json`), depth ≤ 4, excluding `.git`:

| Repo | Files | Repo | Files |
|---|---|---|---|
| GitNexus | 48 | claude-context | 2 |
| repomix | 21 | serena | 2 |
| grepai | 11 | sourcebot | 2 |
| codegraph | 7 | graphify | 1 |
| stakgraph | 4 | gitdiagram | 1 |

## Specific artifacts worth citing

**Auto-connecting MCP server** — `GitNexus/.mcp.json`:

```json
{"mcpServers":{"gitnexus":{"type":"stdio","command":"npx",
 "args":["-y","gitnexus@latest","mcp"]}}}
```

`npx -y ... @latest` fetches and executes whatever is published under that tag at
run time. There is no version pin and no integrity check. Combined with
`GitNexus/gitnexus/.claude/settings.local.json`, which sets
`"enableAllProjectMcpServers": true` and `"enabledMcpjsonServers": ["gitnexus"]`
and pre-allows `Bash(npx gitnexus *)`, `Bash(gh issue *)`, `Bash(gh pr *)`,
`WebSearch`, and third-party memory MCP tools.

**Hooks that fire on every tool call** — `GitNexus/gitnexus-claude-plugin/hooks/hooks.json`
registers a `node` command on `PreToolUse` matching `Grep|Glob|Bash` and on
`PostToolUse` matching `Bash`. `potpie/potpie/cli/templates/claude_plugin/hooks/hooks.json`
registers a `python3` command on `SessionStart`, `PreToolUse`
(`Write|Edit|MultiEdit|NotebookEdit` and `Bash`), `PostToolUse`, and `Stop`.

## Why this matters to the spike

Three distinct points for `security.md` and `red-team.md` to develop:

1. **Untrusted-repo ingestion is an injection channel.** Specera's premise is
   ingesting customer repositories — including dependencies, forks, and
   contractor code. Any repo it ingests may carry agent-directed instructions.
   This spike demonstrated the exposure accidentally, on its own coordinator,
   within minutes of starting. Analysing a repo must not mean adopting its
   instructions.

2. **The competitor pattern is tool-time context injection.** GitNexus and potpie
   both inject graph context via `PreToolUse` hooks rather than through prompts.
   That is a genuine architectural idea to evaluate on the merits — and
   simultaneously the exact mechanism that makes the supply chain dangerous.
   Whatever Specera does here, it inherits both properties.

3. **Pre-granted permissions travel with repos.** A checked-in
   `settings.local.json` carrying an allowlist is a permission-escalation
   primitive that arrives via `git clone`.

## Reproduce

```bash
cd .spike/clones
find . -maxdepth 4 \( -name 'CLAUDE.md' -o -name 'AGENTS.md' -o -name '.cursorrules' \
  -o -path '*/.claude/*' -o -name '.mcp.json' \) -not -path '*/.git/*' | sort
grep -rl '"hooks"' --include='*.json' . | grep -v '/.git/'
```
