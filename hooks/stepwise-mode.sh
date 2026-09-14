#!/bin/bash
# stepwise-mode.sh
# UserPromptSubmit hook — while ~/.claude/state/stepwise-mode.on exists AND is
# owned by the current session, re-inject the stepwise contract on every turn so
# the mode cannot drift out of context in a long conversation.
#
# Session-scoped: the flag file holds the session id that turned it on. A flag
# left behind by an earlier session is stale and gets cleared silently.
#
# Toggled by skills/stepwise. Deliberately kept separate from teach-mode.sh —
# the two modes have different lifetimes and are easier to reason about apart.

FLAG="$HOME/.claude/state/stepwise-mode.on"
CONTRACT="$HOME/.claude/skills/stepwise/references/stepwise-contract.md"

[ -f "$FLAG" ] || exit 0
[ -f "$CONTRACT" ] || exit 0

INPUT=$(cat)
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$SID" ] || SID="$CLAUDE_CODE_SESSION_ID"

OWNER=$(cat "$FLAG" 2>/dev/null)

if [ -z "$OWNER" ]; then
  # Unclaimed flag (toggled without a session id available) — claim it now.
  [ -n "$SID" ] && printf '%s' "$SID" > "$FLAG"
elif [ -n "$SID" ] && [ "$OWNER" != "$SID" ]; then
  # Stale: a previous session left this on. Expire it.
  rm -f "$FLAG"
  exit 0
fi

CONTENT=$(cat "$CONTRACT")
[ -n "$CONTENT" ] || exit 0

CONTEXT_ESCAPED=$(printf '%s' "$CONTENT" | jq -Rs .)

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": $CONTEXT_ESCAPED
  }
}
EOF

exit 0
