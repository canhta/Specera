#!/usr/bin/env bash
# Clone all competitor repos with FULL history into .spike/clones/<repo-name>
# Idempotent: skips repos already cloned.
set -u
ROOT="/home/ubuntu/projects/Specera/.spike/clones"
LOG="/home/ubuntu/projects/Specera/.spike/logs/clone.log"
mkdir -p "$ROOT"
: > "$LOG"

REPOS=(
  "https://github.com/Graphify-Labs/graphify"
  "https://github.com/abhigyanpatwari/GitNexus"
  "https://github.com/potpie-ai/potpie"
  "https://github.com/colbymchenry/codegraph"
  "https://github.com/codegraphcontext/codegraphcontext"
  "https://github.com/stakwork/stakgraph"
  "https://github.com/oraios/serena"
  "https://github.com/yoanbernabeu/grepai"
  "https://github.com/zilliztech/claude-context"
  "https://github.com/sourcebot-dev/sourcebot"
  "https://github.com/sourcegraph/zoekt"
  "https://github.com/oracle/opengrok"
  "https://github.com/yamadashy/repomix"
  "https://github.com/Aider-AI/aider"
  "https://github.com/coderamp-labs/gitingest"
  "https://github.com/mufeedvh/code2prompt"
  "https://github.com/AsyncFuncAI/deepwiki-open"
  "https://github.com/ahmedkhaleel2004/gitdiagram"
  "https://github.com/BloopAI/bloop"
)

clone_one() {
  url="$1"
  name="$(basename "$url")"
  dest="$ROOT/$name"
  if [ -d "$dest/.git" ]; then
    echo "SKIP  $name (already cloned)" >> "$LOG"
    return 0
  fi
  if GIT_TERMINAL_PROMPT=0 git clone --quiet "$url" "$dest" 2>>"$LOG"; then
    echo "OK    $name" >> "$LOG"
  else
    echo "FAIL  $name  $url" >> "$LOG"
  fi
}

# Clone in parallel batches of 5
i=0
for url in "${REPOS[@]}"; do
  clone_one "$url" &
  i=$((i+1))
  if [ $((i % 5)) -eq 0 ]; then wait; fi
done
wait

echo "=== DONE ===" >> "$LOG"
sort "$LOG" | grep -E '^(OK|FAIL|SKIP)' >> "$LOG"
