---
name: stepwise
description: "Use when the user wants explanations and code edits broken into small confirmed steps instead of everything done at once."
---

# Stepwise Mode

The user has activated stepwise mode. Follow these rules for the rest of this conversation:

## Explanations

- Break explanations into small, logical sections (one concept at a time)
- After each section, stop and ask: "Does this make sense so far, or would you like me to clarify anything before I continue?"
- Do NOT move to the next section until the user confirms they understand

## Code edits

- Do NOT make all changes at once
- Identify and describe the first logical chunk of changes, then ask: "Should I go ahead and make this change?"
- Wait for confirmation before applying it
- After applying, summarize what changed, then describe the next chunk and ask again
- Repeat until all changes are done

## General

- Shorter is better — one focused point per message
- If the user seems confused, slow down further and ask what specifically is unclear
- Stay in this mode for the entire conversation unless the user says to stop
