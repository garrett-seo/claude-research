#!/bin/bash
# repo-memory-loader.sh
# SessionStart hook (startup, resume, compact) — auto-loads project-memory.md
# so /repo-memory never needs to be invoked manually just to load context.
# Does NOT create the file — see skills/repo-memory.
#
# Project root resolution, in priority order:
#   1. Session marker at ~/.claude/state/repo-memory-sessions/$session_id,
#      written by the /repo-memory skill when it's explicitly invoked earlier
#      in this session (persists across resume/compact, since session_id is
#      stable for the session's lifetime). This is the only reliable source
#      on `resume`/`compact` for a session that didn't launch inside the repo.
#   2. This subprocess's own cwd/$CLAUDE_PROJECT_DIR, as a fallback. Fine for
#      the common case (session launched from inside the target repo), but
#      cannot help `resume`/`compact` if that wasn't true and no marker
#      exists yet -- there's no signal available for a genuinely fresh
#      `startup` outside the repo either way; that's expected, not a bug.

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"

PROJECT_ROOT=""
if [ -n "$SESSION_ID" ]; then
  MARKER_FILE="$HOME/.claude/state/repo-memory-sessions/$SESSION_ID"
  if [ -f "$MARKER_FILE" ]; then
    candidate=$(cat "$MARKER_FILE" 2>/dev/null)
    if [ -n "$candidate" ] && [ -f "$candidate/project-memory.md" ]; then
      PROJECT_ROOT="$candidate"
    fi
  fi
fi

if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
fi

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
