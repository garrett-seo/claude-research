---
name: stepwise
description: "Use when the user wants to toggle stepwise mode on or off — explanations and code edits broken into small confirmed steps instead of everything done at once. Triggers: /stepwise, /stepwise on, /stepwise off, /stepwise status, 'one step at a time', 'stop doing everything at once', 'turn off stepwise'."
---

# Stepwise Mode Toggle

A hook-enforced mode. Unlike an ordinary skill, it does not fade as the
conversation grows — a `UserPromptSubmit` hook re-injects the contract on every
turn while the flag file exists.

**Session-scoped.** The flag records the session that turned it on. A later
session finds a stale flag and clears it silently, so stepwise never ambushes
unrelated work days later.

## State

| Thing | Path |
|---|---|
| Flag file | `~/.claude/state/stepwise-mode.on` (contains the owning session id) |
| Contract | `skills/stepwise/references/stepwise-contract.md` |
| Hook | `hooks/stepwise-mode.sh` (UserPromptSubmit) |

## What to do

Read the argument the user passed.

### `on` (or no argument while currently off)

```bash
mkdir -p ~/.claude/state && printf '%s' "$CLAUDE_CODE_SESSION_ID" > ~/.claude/state/stepwise-mode.on
```

Then read `references/stepwise-contract.md` and start complying immediately —
do not wait for the hook's next injection.

Confirm in one line: stepwise on, lasts this session, `/stepwise off` to stop.

### `off` (or no argument while currently on)

```bash
rm -f ~/.claude/state/stepwise-mode.on
```

Confirm in one line. Resume normal working immediately.

### `status`

```bash
test -f ~/.claude/state/stepwise-mode.on && echo ON || echo OFF
```

Report it. Change nothing.

### No argument

Check the flag first, then flip it to the opposite state.

## Composing with `/teach`

Independent toggles that stack. With both on, each stepwise chunk runs the
teaching order — problem, purpose, toy example — before the checkpoint
question. See `skills/teach/SKILL.md`.

## Editing the behaviour

Change `references/stepwise-contract.md`. The hook reads that file directly, so
edits take effect on the next turn with no restart and no re-toggle.
