---
name: repo-memory
description: "Use when you need to load or maintain a persistent project-memory.md file inside a specific repo to track ongoing work, decisions, and open questions across sessions."
argument-hint: "[repo-path]"
---

# Repo Memory

Manage a persistent `memory.md` file inside a specific repository to track ongoing work across sessions.

## Invocation

The user may pass a repo path as `$ARGUMENTS`. If empty, use the current working directory.

## Step 1 — Resolve the repo path

- If `$ARGUMENTS` is a non-empty path, use it as the repo root.
- Otherwise use the current working directory.
- Confirm the directory exists before proceeding.

## Step 1.5 — Record the session marker

Write the resolved repo path to `~/.claude/state/repo-memory-sessions/$CLAUDE_CODE_SESSION_ID` (create the directory if needed; one line, just the absolute repo path, no trailing content). This lets the `SessionStart` and `Stop` hooks (`repo-memory-loader.sh`, `repo-memory-updater.sh`) find the right `project-memory.md` directly for the rest of this session — including on a later `resume`/`compact` — instead of inferring it from cwd or edited-file paths, both of which are unreliable when the session didn't launch from inside this repo. Do this silently; don't announce it.

## Step 2 — Load or create memory

Check for `{repo_path}/project-memory.md`:

- **If it exists**: Read the file. Briefly summarize its contents to the user in 2–3 sentences so they know what context has been loaded.
- **If it doesn't exist**: Create it using the template below, then tell the user you've initialized a fresh memory file.

### Template for new files

```markdown
# Repo Memory

_Last updated: {today's date}_

## Current Focus
<!-- What is currently being worked on -->

## Key Decisions
<!-- Architecture and design choices made, with brief rationale -->

## Active Context
<!-- State of current work: what's done, what's in progress, what's blocked -->

## Open Questions / Next Steps
<!-- Unresolved questions and things to follow up on -->

## Key Files & Structure
<!-- Important files, their roles, and how they fit together -->
```

## Step 3 — Work normally

Answer the user's questions and help with tasks as usual. Do not change behavior or ask the user to narrate what to save.

## Step 4 — Update memory after each meaningful exchange

After every exchange where something notable is learned or decided, silently update `{repo_path}/project-memory.md` using the Write or Edit tool. Do **not** announce the update unless the user asks. Use judgment — not every message warrants an update.

### What to capture

- What is currently being worked on and its status
- Decisions made and their rationale (especially non-obvious ones)
- Bugs found, their root cause, and how they were fixed
- Important file paths and their roles
- Open questions, blockers, or next steps
- Anything that would provide useful context at the start of the *next* session

### What to skip

- Trivial or purely transient details
- Information that is obvious from reading the code
- Completed items with no lasting relevance
- The full content of files (summarize instead)

### Format rules

- Keep the file under ~80 lines — prune stale entries as you add new ones
- Update the `_Last updated_` date whenever you write
- Write in terse, factual prose — no fluff
- Preserve the section headings from the template; add sub-headings only if needed

## Step 5 — On explicit `/repo-memory` re-invocation

If the user calls this skill again mid-session (possibly with a different path), re-read the memory file at the new path, overwrite the session marker from Step 1.5 with the new path, and reload context. Continue updating as in Step 4.
