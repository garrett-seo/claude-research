# Hooks

> 14 hook scripts that run automatically at key moments in Claude Code sessions.

Hook scripts live in `hooks/` and are configured in `~/.claude/settings.json` under the `"hooks"` key.

## Overview

| Hook | Trigger | What it does |
|------|---------|-------------|
| `block-destructive-git.sh` | Before Bash | catches dangerous git/shell commands |
| `context-monitor.py` | After tool use | tracks tool call count as a heuristic for context usage |
| `handoff-read.sh` | SessionStart | if handoff.md exists in cwd, read it into additionalContext |
| `pdf-to-markdown.py` | Before Read | converts a PDF to markdown before it is read |
| `postcompact-restore.py` | After compact | restores state after context compression |
| `precompact-autosave.py` | Before compact | saves state before context compression |
| `promise-checker.sh` | Session stop | catches "performative compliance": Claude says it remembered/noted/saved |
| `protect-source-files.sh` | Before edit/write | prompts confirmation for files outside |
| `repo-memory-loader.sh` | SessionStart | auto-loads `project-memory.md` from the current repo root |
| `repo-memory-updater.sh` | Session stop | updates `project-memory.md` at the end of a session |
| `resume-context-loader.sh` | Session resume | surfaces current focus and latest session log |
| `startup-context-loader.sh` | Session start | auto-detects and surfaces project documentation |
| `stepwise-mode.sh` | Before each prompt | while `/stepwise` is on for this session, re-injects the stepwise contract |
| `teach-mode.sh` | Before each prompt | while `/teach` is on for this session, re-injects the teaching contract |

## Hook Events

| Event | When it fires | Matcher options |
|-------|---------------|-----------------|
| `SessionStart` | Session begins | `startup` (fresh), `resume` (continuing), `compact` (after compaction) |
| `UserPromptSubmit` | Before each user prompt reaches Claude | *(empty = always)* |
| `PreToolUse` | Before a tool runs | Tool name(s), e.g. `Bash`, `Edit\|Write` |
| `PostToolUse` | After a tool runs | Tool name(s), e.g. `Bash\|Task` |
| `Stop` | Claude stops responding | *(empty = always)* |
| `PreCompact` | Before context compression | *(empty = always)* |

## Configuration

All hooks are configured in `~/.claude/settings.json`. See the `settings.json` file for the full configuration.

## Creating New Hooks

1. Write a shell or Python script in `hooks/`
2. Add an entry to `~/.claude/settings.json` under the appropriate event key
3. Set the `matcher` to control when it fires
