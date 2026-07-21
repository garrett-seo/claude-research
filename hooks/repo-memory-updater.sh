#!/bin/bash
# repo-memory-updater.sh
# Stop hook — nudges Claude to update project-memory.md after turns that made
# real changes (Edit/Write/NotebookEdit) but didn't touch project-memory.md
# itself. Only active in repos that already have a project-memory.md (see
# skills/repo-memory). Mirrors the block-on-missing-action pattern used by
# promise-checker.sh.

INPUT=$(cat)

# Prevent infinite loops
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
MEMORY_FILE="$PROJECT_ROOT/project-memory.md"

if [ ! -f "$MEMORY_FILE" ]; then
  exit 0
fi

TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# --- Extract the last assistant turn ---
LAST_TURN=$(tac "$TRANSCRIPT_PATH" 2>/dev/null | while IFS= read -r line; do
  MSG_TYPE=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
  if [ "$MSG_TYPE" = "user_message" ]; then
    break
  fi
  echo "$line"
done)

if [ -z "$LAST_TURN" ]; then
  exit 0
fi

# --- Files touched this turn via Edit/Write/NotebookEdit ---
EDITED_FILES=$(echo "$LAST_TURN" | \
  jq -r '.content[]? | select(.type == "tool_use") | select(.name == "Edit" or .name == "Write" or .name == "NotebookEdit") | .input.file_path // empty' \
  2>/dev/null)

if [ -z "$EDITED_FILES" ]; then
  # Nothing was changed this turn — no reason to nudge
  exit 0
fi

if echo "$EDITED_FILES" | grep -F -x -q "$MEMORY_FILE"; then
  # project-memory.md was already updated this turn
  exit 0
fi

# --- Verdict: real changes happened, project-memory.md wasn't touched ---
cat <<EOF
{
  "decision": "block",
  "reason": "You changed files this turn but haven't updated project-memory.md at ${MEMORY_FILE}. If anything from this exchange is worth remembering for future sessions (current focus/status, a non-obvious decision and its rationale, a bug + root cause + fix, an important file path, or an open question/blocker), update it now with Edit — keep it under ~80 lines, pruning stale or completed entries as needed, and update the 'Last updated' date. If nothing here is worth persisting long-term, it is fine to skip and just finish."
}
EOF
exit 0
