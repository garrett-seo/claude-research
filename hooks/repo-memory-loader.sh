#!/bin/bash
# repo-memory-loader.sh
# SessionStart hook (startup, resume) — auto-loads project-memory.md from the
# current repo root, if one exists, so /repo-memory never needs to be invoked
# manually just to load context. Does NOT create the file — see skills/repo-memory.

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
MEMORY_FILE="$PROJECT_ROOT/project-memory.md"

if [ ! -f "$MEMORY_FILE" ]; then
  exit 0
fi

CONTENT=$(cat "$MEMORY_FILE")
if [ -z "$CONTENT" ]; then
  exit 0
fi

CONTEXT="# Project Memory (auto-loaded from project-memory.md)\n${CONTENT}"
CONTEXT_ESCAPED=$(echo -e "$CONTEXT" | jq -Rs .)

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $CONTEXT_ESCAPED
  }
}
EOF

exit 0
