#!/usr/bin/env bash
# build-book-pdf.sh — compile a vault book to a PDF companion.
#
# Pipeline:
#   1. `myst build --tex` writes raw LaTeX to <book>/_build/tex/
#   2. Patch fontenc/inputenc/lmodern → fontspec (xelatex unicode glyphs)
#   3. Patch \section → \chapter (and bump subsection/subsubsection down) so the
#      book class produces proper chapter numbering
#   4. Insert a publication block after \maketitle
#   5. `latexmk -xelatex` → copy to <book>/exports/<slug>.pdf
#
# Usage: build-book-pdf.sh <slug>
#   <slug> must match a directory under ~/Research-Vault/books/ containing a
#   myst.yml with a `format: tex` export.
#
# Exit codes: 0 success, 1 usage/precondition, 2 build error.

set -euo pipefail

SLUG="${1:-}"
if [[ -z "$SLUG" ]]; then
  echo "usage: build-book-pdf.sh <slug>" >&2
  exit 1
fi

BOOK_DIR="$HOME/Research-Vault/books/$SLUG"
if [[ ! -d "$BOOK_DIR" ]]; then
  echo "error: book directory not found: $BOOK_DIR" >&2
  exit 1
fi
if [[ ! -f "$BOOK_DIR/myst.yml" ]]; then
  echo "[0/5] myst.yml not found — bootstrapping from books/index.yaml"
  python3 - "$SLUG" "$BOOK_DIR" <<'PY'
import re, sys, pathlib
slug, book_dir = sys.argv[1], pathlib.Path(sys.argv[2])
idx = (pathlib.Path.home() / "Research-Vault" / "books" / "index.yaml").read_text()
# Find the slug's block; collect title + chapters
title, bib, chapters = None, "references.bib", []
in_block, in_chapters = False, False
for line in idx.splitlines():
    if line.startswith(f"{slug}:"):
        in_block = True; continue
    if in_block:
        if line and not line.startswith((" ", "\t", "#")):
            break
        m = re.match(r'\s*title:\s*"?([^"]+)"?\s*$', line)
        if m: title = m.group(1).strip()
        m = re.match(r'\s*bibliography:\s*(\S+)\s*$', line)
        if m: bib = m.group(1).strip()
        if re.match(r'\s*chapters:\s*$', line):
            in_chapters = True; continue
        if in_chapters:
            m = re.match(r'\s*-\s*(\S+)\s*$', line)
            if m: chapters.append(m.group(1).strip())
            elif line.strip() and not line.startswith(" " * 4):
                in_chapters = False
if not title or not chapters:
    sys.exit("error: could not find title or chapters in books/index.yaml")
articles = "\n".join(f"        - file: {c}.md" for c in chapters)
(book_dir / "myst.yml").write_text(
    "# Bootstrapped by build-book-pdf.sh; safe to extend.\n"
    "version: 1\n"
    "project:\n"
    f'  title: "{title}"\n'
    "  bibliography:\n"
    f"    - {bib}\n"
    "  exports:\n"
    "    - format: tex\n"
    "      template: plain_latex_book\n"
    "      output: _build/tex/\n"
    "      articles:\n"
    f"{articles}\n"
)
print(f"  wrote {book_dir}/myst.yml")
PY
fi

command -v myst    >/dev/null || { echo "error: mystmd not installed (npm install -g mystmd)" >&2; exit 1; }
command -v latexmk >/dev/null || { echo "error: latexmk not on PATH" >&2; exit 1; }
command -v xelatex >/dev/null || { echo "error: xelatex not on PATH" >&2; exit 1; }

cd "$BOOK_DIR"

echo "[1/5] cleaning prior build artefacts"
rm -rf _build exports

echo "[2/5] myst build --tex"
myst build --tex 2>&1 | tail -5

TEX_DIR="_build/tex"
MAIN_TEX="$TEX_DIR/intro.tex"
if [[ ! -f "$MAIN_TEX" ]]; then
  # mystmd names the main file after the first article; fall back to a glob
  MAIN_TEX=$(find "$TEX_DIR" -maxdepth 1 -name "*.tex" -not -name "*-*" | head -1)
fi
if [[ -z "${MAIN_TEX:-}" || ! -f "$MAIN_TEX" ]]; then
  echo "error: could not locate main tex file under $TEX_DIR" >&2
  exit 2
fi

PREFIX=$(basename "$MAIN_TEX" .tex)  # e.g. "intro"

echo "[3/5] patching main tex ($MAIN_TEX)"
# Swap 8-bit font setup for fontspec (xelatex needs this for unicode glyphs
# like ↗ ∈ ─ ├ that mystmd emits in callouts, code blocks, tree diagrams).
# Also compose a custom title page from atlas metadata + myst.yml overrides.
python3 - "$MAIN_TEX" "$BOOK_DIR" "$SLUG" <<'PY'
import re, sys, pathlib

main_tex   = pathlib.Path(sys.argv[1])
book_dir   = pathlib.Path(sys.argv[2])
slug       = sys.argv[3]
vault_root = pathlib.Path.home() / "Research-Vault"

# ---- read atlas topic for canonical publication metadata --------------------
def read_book_index_atlas_topic(slug):
    idx = (vault_root / "books" / "index.yaml").read_text()
    # Find the slug's block and its atlas_topic line
    in_block = False
    for line in idx.splitlines():
        if line.startswith(f"{slug}:"):
            in_block = True
            continue
        if in_block:
            if line and not line.startswith((" ", "\t", "#")):
                break  # next top-level slug
            m = re.match(r'\s*atlas_topic:\s*"?([^"]+)"?\s*$', line)
            if m:
                return m.group(1).strip()
    return None

def read_atlas_meta(atlas_topic):
    """Return dict with paper_title, venue, status from the first outputs entry."""
    if not atlas_topic:
        return {}
    path = vault_root / "atlas" / f"{atlas_topic}.md"
    if not path.exists():
        return {}
    txt = path.read_text()
    meta = {}
    # outputs: is a list; first entry runs until the next top-level key.
    m = re.search(r"^outputs:\s*\n((?:[ -].*\n)+)", txt, re.M)
    if m:
        first = m.group(1)
        for field in ("venue", "status", "paper_title", "format",
                      "camera_ready_submitted"):
            # First field of a YAML list entry starts with "- ", others with
            # leading spaces. Allow either.
            fm = re.search(rf"^[ \-]+{field}:\s*['\"]?([^'\"\n]+?)['\"]?\s*$",
                           first, re.M)
            if fm:
                v = fm.group(1).strip()
                v = re.sub(r"^\[\[(.+)\]\]$", r"\1", v)  # strip wiki brackets
                meta[field] = v
    return meta

def read_myst_overrides(book_dir):
    """Pick up optional doi/arxiv/repo/conference_date/license fields."""
    p = book_dir / "myst.yml"
    if not p.exists():
        return {}
    txt = p.read_text()
    out = {}
    for field in ("doi", "arxiv", "repo", "conference_date", "license",
                  "subtitle"):
        fm = re.search(rf"^\s+{field}:\s*['\"]?([^'\"\n]+?)['\"]?\s*$",
                       txt, re.M)
        if fm:
            out[field] = fm.group(1).strip()
    return out

atlas_topic = read_book_index_atlas_topic(slug)
atlas_meta  = read_atlas_meta(atlas_topic)
overrides   = read_myst_overrides(book_dir)

# myst.yml overrides win over atlas
meta = {**atlas_meta, **{k: v for k, v in overrides.items() if v}}

s = main_tex.read_text()

# Swap the 8-bit font stack for fontspec so xelatex can render the unicode
# glyphs mystmd emits (callout arrows, set membership, box-drawing chars).
# Use Latin Modern via its .otf files (kpsewhich-resolvable on TeX Live)
# plus a small \newunicodechar map for the glyphs lmodern doesn't carry.
font_block = (
    "\\usepackage{fontspec}\n"
    # Latin Modern via the explicit .otf basenames shipped with TeX Live —
    # fontspec resolves via kpathsea so we don't need fontconfig registration.
    "\\setmainfont{lmroman10-regular.otf}[\n"
    "  Path=, BoldFont=lmroman10-bold.otf,\n"
    "  ItalicFont=lmroman10-italic.otf,\n"
    "  BoldItalicFont=lmroman10-bolditalic.otf]\n"
    "\\setsansfont{lmsans10-regular.otf}[\n"
    "  Path=, BoldFont=lmsans10-bold.otf,\n"
    "  ItalicFont=lmsans10-oblique.otf,\n"
    "  BoldItalicFont=lmsans10-boldoblique.otf]\n"
    "\\setmonofont{lmmono10-regular.otf}[\n"
    "  Path=, BoldFont=lmmonolt10-bold.otf,\n"
    "  ItalicFont=lmmono10-italic.otf]\n"
    "\\usepackage{newunicodechar}\n"
    "\\newunicodechar{↗}{$\\nearrow$}\n"
    "\\newunicodechar{∈}{$\\in$}\n"
    "\\newunicodechar{─}{-}\n"
    "\\newunicodechar{├}{|-}\n"
    "\\newunicodechar{└}{`-}\n"
    "\\newunicodechar{│}{|}\n"
    # mystmd emits \rightarrow, \leftarrow, etc. in text mode when the source
    # markdown contains unicode arrows — wrap them in \ensuremath so they work
    # outside of explicit $...$.
    "\\let\\origrightarrow\\rightarrow\n"
    "\\renewcommand{\\rightarrow}{\\ensuremath{\\origrightarrow}}\n"
    "\\let\\origleftarrow\\leftarrow\n"
    "\\renewcommand{\\leftarrow}{\\ensuremath{\\origleftarrow}}\n"
    "\\let\\origRightarrow\\Rightarrow\n"
    "\\renewcommand{\\Rightarrow}{\\ensuremath{\\origRightarrow}}\n"
    "\\let\\origLeftarrow\\Leftarrow\n"
    "\\renewcommand{\\Leftarrow}{\\ensuremath{\\origLeftarrow}}\n"
)
s = re.sub(
    r"\\usepackage\[T1\]\{fontenc\}\s*\n"
    r"\\usepackage\[utf8\]\{inputenc\}\s*\n"
    r"\\usepackage\{lmodern\}\s*\n",
    lambda _m: font_block,
    s,
)

# Compose a custom title page block from atlas meta + myst overrides.
# Folds the publication info onto page 1 (no separate page 2).
pub_lines = []
if meta.get("paper_title"):
    pub_lines.append(
        f"{{\\itshape Companion to:}} {meta['paper_title']}"
    )
venue_bits = []
if meta.get("venue"):
    venue_bits.append(meta["venue"])
if meta.get("status"):
    venue_bits.append(meta["status"])
if meta.get("conference_date"):
    venue_bits.append(meta["conference_date"])
if venue_bits:
    pub_lines.append(" · ".join(venue_bits))
id_bits = []
if meta.get("doi"):
    id_bits.append(f"DOI: \\href{{https://doi.org/{meta['doi']}}}"
                   f"{{{meta['doi']}}}")
if meta.get("arxiv"):
    id_bits.append(f"arXiv: \\href{{https://arxiv.org/abs/{meta['arxiv']}}}"
                   f"{{{meta['arxiv']}}}")
if meta.get("repo"):
    id_bits.append(f"Code: \\href{{{meta['repo']}}}{{{meta['repo']}}}")
if id_bits:
    pub_lines.append(" \\\\\n".join(id_bits))

if pub_lines:
    # Replace \maketitle entirely (book class default appends \newpage which
    # would push our block onto page 2). Compose a custom titlepage that
    # includes title/subtitle/author/date AND the publication info on one page.
    pub_block = (
        "\n% --- custom title page (replaces book-class \\maketitle) ---\n"
        "\\makeatletter\n"
        "\\renewcommand{\\maketitle}{%\n"
        "  \\begin{titlepage}%\n"
        "    \\null\\vfil%\n"
        "    \\begin{center}%\n"
        "      {\\Huge\\bfseries \\@title \\par}%\n"
        "      \\vskip 2em%\n"
        "      {\\large \\@author \\par}%\n"
        "      \\vskip 1em%\n"
        "      {\\small \\@date \\par}%\n"
        "      \\vskip 3em%\n"
        "      \\rule{0.4\\textwidth}{0.4pt}\\\\[1.5em]%\n"
        "      \\small\n"
        + "\\\\[0.6em]\n".join(pub_lines) + "\n"
        "    \\end{center}\\par%\n"
        "    \\@thanks\\vfil\\null%\n"
        "  \\end{titlepage}%\n"
        "}\n"
        "\\makeatother\n"
        "% --- end custom title page ---\n"
    )
    s = s.replace("\\begin{document}", pub_block + "\n\\begin{document}", 1)

main_tex.write_text(s)
PY

echo "[4/5] patching per-chapter tex (section→chapter)"
# Per-chapter files are <PREFIX>-<chapter>.tex. Bump heading depth one level so
# the book class produces 1.x / 2.x / ... chapter numbering instead of 0.x.
# Use Python with sentinels to avoid sed's order-dependent reapplication.
python3 - "$TEX_DIR" "$PREFIX" <<'PY'
import re, sys, pathlib
tex_dir = pathlib.Path(sys.argv[1])
prefix  = sys.argv[2]
pattern = f"{prefix}-*.tex"

REPLACEMENTS = [
    (r"\\section\*?\{",       r"\chapter{"),
    (r"\\subsection\*?\{",    r"\section{"),
    (r"\\subsubsection\*?\{", r"\subsection{"),
    (r"\\paragraph\{",        r"\subsubsection{"),
]

for chap in tex_dir.glob(pattern):
    s = chap.read_text()
    # Sentinel pass to avoid re-application
    for i, (src, _) in enumerate(REPLACEMENTS):
        s = re.sub(src, f"@@H{i}@@{{", s)
    for i, (_, dst) in enumerate(REPLACEMENTS):
        s = s.replace(f"@@H{i}@@{{", dst)
    # mystmd emits unicode arrows as bare \rightarrow etc. — TeX glues them
    # to following letters (\rightarrowPS → undefined cs). Insert {} to
    # terminate the control sequence when followed by a letter.
    s = re.sub(r"(\\(?:right|left|up|down|Right|Left|Up|Down)arrow)([A-Za-z])",
               r"\1{}\2", s)
    chap.write_text(s)
PY

echo "[5/5] latexmk -xelatex"
cd "$TEX_DIR"
latexmk -xelatex -interaction=nonstopmode -halt-on-error "$(basename "$MAIN_TEX")" >/dev/null 2>&1 || {
  echo "warning: latexmk had errors; see $BOOK_DIR/$TEX_DIR/$(basename "$MAIN_TEX" .tex).log" >&2
}

PDF_NAME="$(basename "$MAIN_TEX" .tex).pdf"
if [[ ! -f "$PDF_NAME" ]]; then
  echo "error: PDF not produced — inspect $BOOK_DIR/$TEX_DIR/$(basename "$MAIN_TEX" .tex).log" >&2
  exit 2
fi

cd "$BOOK_DIR"
mkdir -p exports
cp "$TEX_DIR/$PDF_NAME" "exports/$SLUG.pdf"
echo "done → $BOOK_DIR/exports/$SLUG.pdf"
