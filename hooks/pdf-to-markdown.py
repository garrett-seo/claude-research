#!/usr/bin/env python3
"""
PreToolUse hook: intercepts Read tool calls on .pdf files,
converts them to markdown via pymupdf4llm, and redirects the
read to the resulting _text.md file.
"""
import sys
import json
import os
import hashlib
import tempfile


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return

    file_path = data.get("tool_input", {}).get("file_path", "")

    if not file_path.lower().endswith(".pdf"):
        return

    pdf_hash = hashlib.md5(file_path.encode()).hexdigest()[:8]
    pdf_name = os.path.splitext(os.path.basename(file_path))[0]
    md_path = os.path.join(tempfile.gettempdir(), f"claude_pdf_{pdf_name}_{pdf_hash}.md")

    if not os.path.exists(md_path):
        try:
            import pymupdf4llm
            md = pymupdf4llm.to_markdown(file_path)
            with open(md_path, "w", encoding="utf-8") as f:
                f.write(md)
        except ImportError:
            result = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": (
                        "pymupdf4llm is not installed. "
                        "Run: uv pip install pymupdf4llm  "
                        "then retry."
                    ),
                }
            }
            print(json.dumps(result))
            return
        except Exception:
            return

    original_input = data.get("tool_input", {}).copy()
    original_input["file_path"] = md_path
    original_input.pop("limit", None)
    original_input.pop("offset", None)
    original_input.pop("pages", None)

    result = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "updatedInput": original_input,
        }
    }
    print(json.dumps(result))


if __name__ == "__main__":
    main()
