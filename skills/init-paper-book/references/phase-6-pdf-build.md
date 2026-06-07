# Phase 6: Build PDF companion (soft-fail)

After Phase 5 lands the registry entry, atlas reload, and smoke test, build a PDF companion alongside the HTML book. Atlas remains the canonical reader surface; the PDF is a shareable, paginated artifact for those who want one.

## Invocation

```bash
bash ~/.claude/skills/init-paper-book/scripts/build-book-pdf.sh <slug>
```

Output: `~/Research-Vault/books/<slug>/exports/<slug>.pdf`.

The script is generic — any vault book with an `index.yaml` registry entry can be built. No per-book code needed.

## What the script does

1. `myst build --tex` → writes raw LaTeX to `<book>/_build/tex/`
2. Patches the main `.tex`:
   - Swaps 8-bit `fontenc+inputenc+lmodern` for `fontspec` with explicit `.otf` paths (xelatex unicode glyph support)
   - Adds a `\newunicodechar` map for box-drawing / arrow glyphs mystmd emits
   - Adds `\ensuremath` wrappers for bare `\rightarrow` / `\leftarrow` / etc. so they survive text mode
   - Replaces book-class `\maketitle` with a custom titlepage that folds publication info onto page 1
3. Patches each chapter `.tex`:
   - `\section{...}` → `\chapter{...}` (so chapter counter advances; 0.x → 1.x numbering)
   - Bumps `\subsection` → `\section`, `\subsubsection` → `\subsection`, `\paragraph` → `\subsubsection`
   - Inserts `{}` after `\rightarrow`-family commands followed by letters (TeX gobble-bug)
4. `latexmk -xelatex` → copies result to `exports/<slug>.pdf`

## Dependencies

| Tool | Install |
|------|---------|
| `mystmd` v1.10+ | `npm install -g mystmd` |
| `xelatex` | MacTeX / TeX Live |
| `latexmk` | bundled with MacTeX |
| `python3` | system |

If `mystmd` is missing, the script exits with a one-line error and the overall init pipeline continues (PDF is non-blocking).

## Soft-fail contract

- Missing `mystmd` → log warning, continue
- Missing `myst.yml` → script auto-bootstraps one from `~/Research-Vault/books/index.yaml`
- `latexmk` non-zero exit → warn, point at the build log, continue (a partial PDF may have been written)
- Missing or unresolved cross-references (e.g. `#sec-foo` not found) → mystmd warns at build time, doesn't block

The init pipeline never blocks on PDF errors. Atlas HTML rendering is canonical; the PDF is a derived artifact.

## Publication info on the title page

The custom title page reads from two sources:

| Source | Fields |
|--------|--------|
| Atlas topic (`~/Research-Vault/atlas/<theme>/<slug>.md`) | `paper_title`, `venue`, `status` from `outputs[0]` |
| `<book>/myst.yml` | `subtitle`, `conference_date`, `doi`, `arxiv`, `repo`, `license` (overrides win) |

The atlas topic is the canonical record. Per-book overrides in `myst.yml` fill fields atlas doesn't carry (conference dates, repo URLs, license).

## When to skip

- The user passes `--no-pdf` to `/init-paper-book` (future flag; not yet wired)
- The book has no `index.yaml` registry entry (means Phase 5 didn't run — Phase 6 has nothing to do)
