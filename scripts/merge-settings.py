#!/usr/bin/env python3
"""merge-settings.py — merge repo hook entries into a live ~/.claude/settings.json.

Used by setup.sh / setup.ps1 when ~/.claude/settings.json already exists, so new
hooks added to the repo's .claude/settings.json (across a `git pull`) actually get
registered instead of silently sitting unused. Never overwrites unrelated keys
(permissions, etc.) and never registers the same command twice under one event.

Usage: merge-settings.py <repo_settings.json> <live_settings.json>
"""
import json
import shutil
import sys


def main():
    if len(sys.argv) != 3:
        print("usage: merge-settings.py <repo_settings.json> <live_settings.json>", file=sys.stderr)
        sys.exit(1)

    repo_path, live_path = sys.argv[1], sys.argv[2]

    with open(repo_path, encoding="utf-8") as f:
        repo = json.load(f)
    with open(live_path, encoding="utf-8") as f:
        live = json.load(f)

    live_hooks = live.setdefault("hooks", {})
    added = []

    for event_name, repo_entries in repo.get("hooks", {}).items():
        live_entries = live_hooks.setdefault(event_name, [])

        for repo_entry in repo_entries:
            matcher = repo_entry.get("matcher", "")
            target = next((e for e in live_entries if e.get("matcher") == matcher), None)
            if target is None:
                target = {"matcher": matcher, "hooks": []}
                live_entries.append(target)

            # Uniqueness is scoped to this (event, matcher) pair — the same
            # command legitimately needs separate registration under each
            # distinct matcher (e.g. "startup" and "resume" both need it).
            existing_commands = {h.get("command") for h in target.get("hooks", [])}

            for hook_obj in repo_entry.get("hooks", []):
                command = hook_obj.get("command")
                if command in existing_commands:
                    continue

                target.setdefault("hooks", []).append(hook_obj)
                existing_commands.add(command)
                added.append(f"{event_name} ({matcher or 'any'}): {command}")

    if not added:
        print("[setup] settings.json hooks already up to date")
        return

    shutil.copy2(live_path, live_path + ".bak")
    with open(live_path, "w", encoding="utf-8") as f:
        json.dump(live, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"[setup] merged {len(added)} new hook(s) into {live_path} (backup: {live_path}.bak)")
    for entry in added:
        print(f"[setup]   + {entry}")


if __name__ == "__main__":
    main()
