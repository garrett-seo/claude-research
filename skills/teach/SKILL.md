---
name: teach
description: "Use when the user wants to toggle teach mode on or off — plain-language explanations that lead with the problem a concept was built to solve, then a worked toy example. Triggers: /teach, /teach on, /teach off, /teach status, 'dumb it down', 'explain it simply', 'turn off teach mode'."
---

# Teach Mode Toggle

A hook-enforced mode. Unlike an ordinary skill, it does not fade as the
conversation grows — a `UserPromptSubmit` hook re-injects the contract on every
turn while the flag file exists.

**Session-scoped.** The flag records the session that turned it on. A later
session finds a stale flag and clears it silently, so the mode never carries
into unrelated work days later.

## State

| Thing | Path |
|---|---|
| Flag file | `~/.claude/state/teach-mode.on` (contains the owning session id) |
| Contract | `skills/teach/references/teaching-contract.md` |
| Hook | `hooks/teach-mode.sh` (UserPromptSubmit) |

## What to do

Read the argument the user passed.

### `on` (or no argument while currently off)

```bash
mkdir -p ~/.claude/state && printf '%s' "$CLAUDE_CODE_SESSION_ID" > ~/.claude/state/teach-mode.on
```

Then read `references/teaching-contract.md` and start complying immediately —
do not wait for the hook's next injection.

Confirm in one line: teach mode on, lasts this session, `/teach off` to stop.

### `off` (or no argument while currently on)

```bash
rm -f ~/.claude/state/teach-mode.on
```

Confirm in one line. Drop the teaching structure immediately.

### `status`

```bash
test -f ~/.claude/state/teach-mode.on && echo ON || echo OFF
```

Report it. Change nothing.

### No argument

Check the flag first, then flip it to the opposite state.

## Composing with `/stepwise`

Independent toggles that stack. With both on, each stepwise chunk follows the
teaching order — problem, purpose, toy example — before the "does this make
sense?" checkpoint. See `skills/stepwise/SKILL.md`.

## Editing the behaviour

Change `references/teaching-contract.md`. The hook reads that file directly, so
edits take effect on the next turn with no restart and no re-toggle.
