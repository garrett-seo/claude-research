#!/bin/bash
# repo-memory-updater.sh
# Stop hook — nudges Claude to update project-memory.md after turns that made
# real changes (Edit/Write/NotebookEdit) but didn't touch project-memory.md
# itself. Only active in repos that already have a project-memory.md (see
# skills/repo-memory). Mirrors the block-on-missing-action pattern used by
# promise-checker.sh.
#
# Project root resolution, in priority order:
#   1. Session marker at ~/.claude/state/repo-memory-sessions/$session_id,
#      written by the /repo-memory skill when it's explicitly invoked. This
#      is the reliable path -- explicit, not inferred.
#   2. Walk up from an actually-edited file's path looking for the nearest
#      project-memory.md. Works even without a marker, but only covers turns
#      that touched a file inside the tracked repo.
#   3. This subprocess's own cwd/$CLAUDE_PROJECT_DIR, as a last resort. Both
#      are fixed at session launch and do NOT track a later `cd` into a
#      project subdirectory -- unreliable, kept only as a final fallback.

LOG_FILE="$HOME/.claude/state/repo-memory-updater.log"
mkdir -p "$(dirname "$LOG_FILE")"
log() {
  echo "$(date -Iseconds) [$$] $1" >> "$LOG_FILE"
}

log "invoked"

INPUT=$(cat)

# Prevent infinite loops
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_ACTIVE" = "true" ]; then
  log "exit: stop_hook_active=true"
  exit 0
fi

# --- Priority 1: explicit session marker ---
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
[ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
MARKER_FILE=""
if [ -n "$SESSION_ID" ]; then
  MARKER_FILE="$HOME/.claude/state/repo-memory-sessions/$SESSION_ID"
fi
MARKER_ROOT=""
if [ -n "$MARKER_FILE" ] && [ -f "$MARKER_FILE" ]; then
  MARKER_ROOT=$(cat "$MARKER_FILE" 2>/dev/null)
  # Marker is only trustworthy if it still actually has a project-memory.md
  if [ -z "$MARKER_ROOT" ] || [ ! -f "$MARKER_ROOT/project-memory.md" ]; then
    MARKER_ROOT=""
  fi
fi
log "session_id=$SESSION_ID marker_file=$MARKER_FILE marker_root=$MARKER_ROOT"

TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  log "exit: no usable transcript_path (got '$TRANSCRIPT_PATH')"
  exit 0
fi
log "transcript_path=$TRANSCRIPT_PATH"

# --- Extract the last assistant turn ---
# A transcript line is a genuine user-turn boundary when type=="user" and its
# first content block is NOT "tool_result" (tool results also come back as
# type=="user" entries, but they're feedback within the current turn, not a
# new human turn). NOTE: the old check compared against a literal
# "user_message" type value that never appears in this transcript schema, so
# it never matched and this loop silently consumed the entire transcript
# instead of just the last turn.
LAST_TURN=$(tac "$TRANSCRIPT_PATH" 2>/dev/null | while IFS= read -r line; do
  IS_BOUNDARY=$(echo "$line" | jq -r 'if .type == "user" and ((.message.content[0].type // "") != "tool_result") then "yes" else "no" end' 2>/dev/null)
  if [ "$IS_BOUNDARY" = "yes" ]; then
    break
  fi
  echo "$line"
done)

if [ -z "$LAST_TURN" ]; then
  log "exit: LAST_TURN extraction was empty"
  exit 0
fi

# --- Files touched this turn via Edit/Write/NotebookEdit ---
# NOTE: tool_use blocks live at .message.content[], not top-level .content[].
# The old .content[]? path never matched anything, so EDITED_FILES was always
# empty and the hook exited via the branch below on every invocation.
EDITED_FILES=$(echo "$LAST_TURN" | \
  jq -r '.message.content[]? | select(.type == "tool_use") | select(.name == "Edit" or .name == "Write" or .name == "NotebookEdit") | .input.file_path // empty' \
  2>/dev/null)

if [ -z "$EDITED_FILES" ]; then
  # Nothing was changed this turn — no reason to nudge
  log "exit: no Edit/Write/NotebookEdit calls found in last turn"
  exit 0
fi
log "edited_files: $(echo "$EDITED_FILES" | tr '\n' '|')"

# --- Resolve project root by walking up from an edited file's directory,
#     looking for the nearest project-memory.md ---
_find_project_memory_root() {
  local dir="$1"
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -f "$dir/project-memory.md" ]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

PROJECT_ROOT="$MARKER_ROOT"
[ -n "$PROJECT_ROOT" ] && log "project_root via priority 1 (marker): $PROJECT_ROOT"

# Priority 2: walk up from an actually-edited file's path.
if [ -z "$PROJECT_ROOT" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    candidate=$(_find_project_memory_root "$(dirname "$f")")
    if [ -n "$candidate" ]; then
      PROJECT_ROOT="$candidate"
      log "project_root via priority 2 (walk-up from $f): $PROJECT_ROOT"
      break
    fi
  done <<< "$EDITED_FILES"
fi

# Priority 3: last resort, in case a future harness passes a live, correct cwd.
if [ -z "$PROJECT_ROOT" ]; then
  FALLBACK_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  if [ -f "$FALLBACK_ROOT/project-memory.md" ]; then
    PROJECT_ROOT="$FALLBACK_ROOT"
    log "project_root via priority 3 (fallback cwd/git-root): $PROJECT_ROOT"
  fi
fi

if [ -z "$PROJECT_ROOT" ]; then
  # None of the edited files belong to a project using project-memory.md
  log "exit: no project_root resolved by any priority"
  exit 0
fi

MEMORY_FILE="$PROJECT_ROOT/project-memory.md"

if echo "$EDITED_FILES" | grep -F -x -q "$MEMORY_FILE"; then
  # project-memory.md was already updated this turn
  log "exit: $MEMORY_FILE already edited this turn"
  exit 0
fi

log "BLOCKING: nudging Claude to update $MEMORY_FILE"

# --- Verdict: real changes happened, project-memory.md wasn't touched ---
cat <<EOF
{
  "decision": "block",
  "reason": "You changed files this turn but haven't updated project-memory.md at ${MEMORY_FILE}. If anything from this exchange is worth remembering for future sessions (current focus/status, a non-obvious decision and its rationale, a bug + root cause + fix, an important file path, or an open question/blocker), update it now with Edit — keep it under ~80 lines, pruning stale or completed entries as needed, and update the 'Last updated' date. If nothing here is worth persisting long-term, it is fine to skip and just finish."
}
EOF
log "decision emitted, exiting"
exit 0
