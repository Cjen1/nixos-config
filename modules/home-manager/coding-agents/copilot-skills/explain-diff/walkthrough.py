# /// script
# requires-python = ">=3.10"
# dependencies = ["tree-sitter==0.25.2", "tree-sitter-language-pack"]
# ///
"""Render a git diff as a two-column guided walkthrough (diff left, comments right).

Library:
    from walkthrough import render_walkthrough
    render_walkthrough(repo, base, head, comments, "out.html", title="...")

Shell:
    uv run walkthrough.py BASE HEAD comments.json -o out.html [--repo .] [--title T]

comments: list of (path, start_line, end_line, text) in walkthrough order.
Lines are head-side (the file as it is at HEAD), inclusive. Text is plain text;
the first line is the step title and blank lines separate paragraphs.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Sequence

Comment = tuple[str, int, int, str]

LANGUAGES = {
    ".c": "c", ".h": "cpp", ".cc": "cpp", ".cpp": "cpp", ".cxx": "cpp", ".hpp": "cpp",
    ".py": "python", ".rs": "rust", ".go": "go", ".java": "java", ".cs": "csharp",
    ".js": "javascript", ".mjs": "javascript", ".jsx": "javascript",
    ".ts": "typescript", ".tsx": "tsx", ".rb": "ruby", ".kt": "kotlin",
    ".swift": "swift", ".scala": "scala", ".lean": "lean", ".nix": "nix",
    ".sh": "bash", ".lua": "lua", ".php": "php", ".hs": "haskell", ".ml": "ocaml",
}
# Definition-like nodes give useful context; control flow does not.
SCOPE_WORDS = ("function", "method", "class", "struct", "namespace", "impl", "trait",
               "interface", "enum", "union", "module", "mod_item", "object")
CONTROL_PREFIXES = ("if", "for", "while", "switch", "case", "try", "catch", "lambda", "closure")
MAX_HEADER_LINES = 8


@dataclass
class Row:
    kind: str  # "+", "-", " " for diff rows; "scope" / "folded" for unchanged head lines
    old: int | None
    new: int | None
    code: str
    anchor: int  # head-side position; removed lines take the next head line


@dataclass
class FileDiff:
    path: str
    hunks: list[list[Row]] = field(default_factory=list)


def git(repo: Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(repo), *args], check=True,
                          capture_output=True, text=True).stdout


def parse_diff(text: str) -> list[FileDiff]:
    files: list[FileDiff] = []
    old_path = None
    old = new = 0
    for line in text.splitlines():
        if line.startswith("diff --git "):
            old_path = None
        elif line.startswith("--- "):
            old_path = None if line == "--- /dev/null" else line[6:]
        elif line.startswith("+++ "):
            files.append(FileDiff(old_path if line == "+++ /dev/null" else line[6:]))
        elif line.startswith("@@"):
            m = re.match(r"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
            old, new = map(int, m.groups())
            files[-1].hunks.append([])
        elif files and files[-1].hunks and line[:1] in (" ", "+", "-"):
            kind = line[0]
            files[-1].hunks[-1].append(Row(kind, old if kind != "+" else None,
                                           new if kind != "-" else None, line[1:], max(new, 1)))
            old += kind != "+"
            new += kind != "-"
    return files


def scopes_for(path: str, source: bytes) -> list[tuple[int, int, int, bool]]:
    """(start, header_end, end, has_closer) for each definition-like scope."""
    lang = LANGUAGES.get(Path(path).suffix.lower())
    if lang is None:
        return []
    try:
        from tree_sitter_language_pack import get_parser
        tree = get_parser(lang).parse(source)
    except Exception:
        return []
    lines = source.split(b"\n")
    scopes = []

    def add(start_node, body):
        start = start_node.start_point.row + 1
        braced = source[body.start_byte:body.start_byte + 1] in (b"{", b"(", b"[")
        header_end = body.start_point.row + 1 if braced else body.start_point.row
        header_end = min(max(start, header_end), start + MAX_HEADER_LINES)
        end = body.end_point.row + 1
        closer = braced and lines[end - 1].strip()[:1] in (b"}", b")", b"]")
        scopes.append((start, header_end, end, closer))

    def walk(node):
        body = node.child_by_field_name("body")
        t = node.type
        if (body is not None and node.start_point.row != node.end_point.row
                and any(w in t for w in SCOPE_WORDS) and not t.startswith(CONTROL_PREFIXES)):
            add(node, body)
        previous = None
        for child in node.children:
            # C/C++ test macros, e.g. TEST_CASE("x") { ... }, parse as a call + bare block.
            if (child.type == "compound_statement" and previous is not None
                    and previous.type == "expression_statement"
                    and re.match(rb"\s*[A-Z_][A-Z0-9_]*\s*\(", source[previous.start_byte:previous.end_byte])):
                add(previous, child)
            walk(child)
            if child.type != "comment":
                previous = child

    walk(tree.root_node)
    return scopes


def build_rows(diff: FileDiff, head_lines: list[str], keep: set[int]) -> list[Row]:
    """Interleave hunks with unchanged head lines: kept lines shown, the rest folded."""
    rows: list[Row] = []

    def context(start: int, end: int) -> None:
        for n in range(start, end + 1):
            rows.append(Row("scope" if n in keep else "folded", None, n, head_lines[n - 1], n))

    cursor = 1
    for hunk in diff.hunks:
        heads = [r.new for r in hunk if r.new is not None]
        if heads:
            context(cursor, min(heads) - 1)
            cursor = max(heads) + 1
        rows.extend(hunk)
    context(cursor, len(head_lines))
    return rows


def esc(value) -> str:
    return html.escape(str(value), quote=True)


def render_rows(rows: list[Row]) -> str:
    out, i = [], 0
    while i < len(rows):
        r = rows[i]
        if r.kind == "folded":
            j = i
            while j < len(rows) and rows[j].kind == "folded":
                j += 1
            n = j - i
            out.append(f'<tr class="fold"><td colspan="4"><button class="expand" type="button">'
                       f'&#8943; {n} line{"s" if n != 1 else ""}</button></td></tr>')
            out.extend(f'<tr class="folded" hidden data-a="{f.anchor}"><td class="ln"></td><td class="ln">{f.new}</td>'
                       f'<td class="sign"></td><td class="src">{esc(f.code)}</td></tr>' for f in rows[i:j])
            i = j
            continue
        cls = {"+": "add", "-": "del", " ": "ctx", "scope": "scope"}[r.kind]
        sign = r.kind if r.kind in ("+", "-") else ""
        out.append(f'<tr class="{cls}" data-a="{r.anchor}"><td class="ln">{r.old or ""}</td>'
                   f'<td class="ln">{r.new or ""}</td><td class="sign">{sign}</td>'
                   f'<td class="src">{esc(r.code)}</td></tr>')
        i += 1
    return "".join(out)


def render_walkthrough(repo: str | Path, base: str, head: str, comments: Sequence[Comment],
                       output: str | Path, title: str = "") -> Path:
    """Write a self-contained HTML walkthrough of `git diff base head`; return its path."""
    repo = Path(repo)
    files = parse_diff(git(repo, "diff", "--no-color", "--no-ext-diff", "-M", "--unified=3", base, head))
    by_path = {f.path: f for f in files}
    comments = [(str(p), int(s), int(e), str(t)) for p, s, e, t in comments]

    heads: dict[str, list[str]] = {}
    for f in files:
        try:
            heads[f.path] = git(repo, "show", f"{head}:{f.path}").splitlines()
        except subprocess.CalledProcessError:
            heads[f.path] = []  # deleted at head
        last = max(len(heads[f.path]), 1)
        for hunk in f.hunks:
            for r in hunk:
                r.anchor = min(r.anchor, last)  # deletions at end of file
    for path, start, end, _ in comments:
        if path not in by_path:
            raise ValueError(f"Comment on {path}, which is not in the diff {base}..{head}")
        n = len(heads[path])
        if not 1 <= start <= end <= max(n, 1):
            raise ValueError(f"Comment range {path}:{start}-{end} is outside the head file (1-{n})")

    sections, nav = [], []
    for index, f in enumerate(files):
        changed = {r.anchor for h in f.hunks for r in h if r.kind != " "}
        keep: set[int] = set()
        for start, header_end, end, closer in scopes_for(f.path, "\n".join(heads[f.path]).encode()):
            if any(start <= line <= end for line in changed):
                keep.update(range(start, header_end + 1))
                if closer:
                    keep.add(end)
        file_comments = [i for i, c in enumerate(comments) if c[0] == f.path]
        for i in file_comments:
            keep.update(range(comments[i][1], comments[i][2] + 1))  # commented lines stay visible
        rows = build_rows(f, heads[f.path], keep)

        # Split into chunks at each comment's first line so its note sits beside it.
        starts: dict[int, list[int]] = {}
        for i in file_comments:
            starts.setdefault(comments[i][1], []).append(i)
        chunks: list[tuple[list[int], list[Row]]] = [([], [])]
        for r in rows:
            if r.kind != "-" and r.anchor in starts:
                chunks.append((starts.pop(r.anchor), []))
            chunks[-1][1].append(r)
        body = []
        for ids, chunk_rows in chunks:
            if not chunk_rows:
                continue
            notes = "".join(
                f'<div class="note" id="note-{i}" data-step="{i}"><div class="step-no">Step {i + 1}</div>'
                + "".join(f"<p>{esc(p.strip())}</p>" for p in re.split(r"\n\s*\n", comments[i][3]) if p.strip())
                + "</div>" for i in ids)
            body.append(f'<div class="chunk{" has-note" if ids else ""}"><div class="code"><table><tbody>'
                        f'{render_rows(chunk_rows)}</tbody></table></div><aside>{notes}</aside></div>')
        sections.append(f'<section class="file" id="file-{index}"><h2>{esc(f.path)}</h2>{"".join(body)}</section>')
        nav.append(f'<option value="file-{index}">{esc(f.path)}</option>')

    steps = [{"start": s, "end": e, "title": (t.strip().splitlines() or [""])[0][:90]}
             for _, s, e, t in comments]
    page = (TEMPLATE
            .replace("{{TITLE}}", esc(title or f"{base[:9]}..{head[:9]}"))
            .replace("{{RANGE}}", esc(f"{base}..{head}"))
            .replace("{{NAV}}", "".join(nav))
            .replace("{{CONTENT}}", "".join(sections))
            .replace("{{STEPS}}", json.dumps(steps).replace("</", "<\\/")))
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(page)
    for path, lines in uncovered_changes(files, comments).items():
        print(f"uncommented changes: {path}: {format_ranges(lines)}", file=sys.stderr)
    return output


def uncovered_changes(files: list[FileDiff], comments: Sequence[Comment]) -> dict[str, list[int]]:
    """Head-side lines of added/removed rows that no comment range covers."""
    result = {}
    for f in files:
        ranges = [(s, e) for p, s, e, _ in comments if p == f.path]
        lines = sorted({r.anchor for h in f.hunks for r in h if r.kind != " "
                        and not any(s <= r.anchor <= e for s, e in ranges)})
        if lines:
            result[f.path] = lines
    return result


def format_ranges(lines: list[int]) -> str:
    spans, start = [], lines[0]
    for prev, cur in zip(lines, lines[1:] + [None]):
        if cur != prev + 1:
            spans.append(f"{start}" if start == prev else f"{start}-{prev}")
            start = cur
    return ", ".join(spans)


TEMPLATE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{{TITLE}}</title>
<style>
:root{--border:#d3dce6;--ink:#192b3b;--muted:#526578}
*{box-sizing:border-box}body{margin:0;height:100dvh;display:grid;grid-template-rows:auto minmax(0,1fr);background:#f5f7fa;color:var(--ink);font:15px/1.55 system-ui,sans-serif}
header{z-index:5;background:#fff;border-bottom:1px solid var(--border);padding:12px 22px;box-shadow:0 2px 8px #1020300a}
.bar{display:flex;gap:14px;align-items:center;flex-wrap:wrap}h1{font-size:17px;margin:0;margin-right:auto}
.range{color:var(--muted);font:12px ui-monospace,monospace;margin-top:4px}
label{font-size:13px;font-weight:650}select{padding:6px;border:1px solid #a5b5c4;border-radius:5px;background:#fff;color:var(--ink);max-width:min(60vw,560px)}
.buttons{display:flex;gap:8px}button.nav{background:#eaf1f9;border:1px solid #a5b5c4;border-radius:5px;padding:6px 14px;color:var(--ink);cursor:pointer}
button.nav:disabled{opacity:.4;cursor:default}
main{overflow:auto;padding:0 16px 60vh}.file{margin:22px 0;border:1px solid var(--border);background:#fff;border-radius:7px;overflow:clip}
h2{position:sticky;top:0;z-index:4;font:600 14px/1.5 ui-monospace,monospace;padding:12px 16px;margin:0;background:#e9eef4;overflow-wrap:anywhere}
.chunk{display:grid;grid-template-columns:minmax(0,64fr) minmax(260px,36fr);scroll-margin-top:110px}
.chunk.has-note{border-top:1px solid #e3e9ef}
.code{overflow-x:auto;min-width:0}table{border-collapse:collapse;width:100%;font:12px/1.6 ui-monospace,SFMono-Regular,Consolas,monospace}
td{vertical-align:top;padding:0}.ln{width:46px;min-width:46px;text-align:right;padding:0 8px;color:#83909d;user-select:none}
.sign{width:20px;min-width:20px;text-align:center;user-select:none}.src{white-space:pre;padding-right:16px}
.add{background:#e5f5ea}.del{background:#fde9e7}.add .sign{color:#19753d}.del .sign{color:#b83531}
.scope td{background:#f6f8fb}.scope .src{color:#27496b}.folded td{background:#fbfcfd}.folded .src{color:#5b6875}
.fold td{background:#f3f5f8;border-top:1px dashed #dde3ea;border-bottom:1px dashed #dde3ea}
.expand{background:none;border:0;color:#8994a1;cursor:pointer;font:12px/1.7 ui-monospace,monospace;padding:0 0 0 64px;width:100%;text-align:left}
.expand:hover{color:#17619c;background:#eaf1f9}
tr.in-step td.ln:first-child{box-shadow:inset 3px 0 #347db4}
aside{border-left:1px solid var(--border);background:#fcfdff;min-width:0}
.note{position:sticky;top:110px;padding:14px 18px;opacity:.55;cursor:pointer}.note p{margin:0 0 10px}
.note.active{opacity:1;cursor:default;background:#eef5fc;box-shadow:inset 3px 0 #347db4}
.step-no{font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);margin-bottom:4px}
.note p:first-of-type{font-weight:650}
@media(max-width:800px){header{position:relative}.chunk{grid-template-columns:minmax(0,1fr)}aside{border-left:0}.note{position:static}main{padding:0 6px 40vh}}
</style></head><body>
<header><div class="bar"><h1>{{TITLE}}</h1>
<label>Step <select id="step"></select></label>
<label>File <select id="file">{{NAV}}</select></label>
<span class="buttons"><button class="nav" id="prev" type="button">Previous</button><button class="nav" id="next" type="button">Next</button></span></div>
<div class="range">{{RANGE}} &middot; keys: &larr; / &rarr;</div></header>
<main>{{CONTENT}}</main>
<script>
const steps={{STEPS}};let current=0;
const stepSelect=document.getElementById('step');
steps.forEach((s,i)=>{const o=document.createElement('option');o.value=i;o.textContent=`${i+1}. ${s.title}`;stepSelect.append(o);});
function expand(fold){for(let r=fold.nextElementSibling;r&&r.classList.contains('folded');r=r.nextElementSibling)r.hidden=false;fold.hidden=true;}
function unfold(row){
 if(!row.hidden)return;
 let r=row;while(r.previousElementSibling&&r.previousElementSibling.classList.contains('folded'))r=r.previousElementSibling;
 if(r.previousElementSibling&&r.previousElementSibling.classList.contains('fold'))expand(r.previousElementSibling);
}
function show(i){
 if(!steps.length)return;
 current=Math.max(0,Math.min(steps.length-1,i));stepSelect.value=String(current);
 document.querySelectorAll('.note.active').forEach(n=>n.classList.remove('active'));
 document.querySelectorAll('tr.in-step').forEach(r=>r.classList.remove('in-step'));
 const s=steps[current],note=document.getElementById(`note-${current}`);note.classList.add('active');
 note.closest('.file').querySelectorAll('tr[data-a]').forEach(r=>{const a=Number(r.dataset.a);
  if(a>=s.start&&a<=s.end){r.classList.add('in-step');unfold(r);}});
 document.getElementById('prev').disabled=current===0;
 document.getElementById('next').disabled=current===steps.length-1;
 note.closest('.chunk').scrollIntoView({behavior:'instant',block:'start'});
}
document.querySelectorAll('.expand').forEach(b=>b.addEventListener('click',()=>expand(b.closest('tr'))));
stepSelect.addEventListener('change',e=>show(Number(e.target.value)));
document.getElementById('prev').addEventListener('click',()=>show(current-1));
document.getElementById('next').addEventListener('click',()=>show(current+1));
document.getElementById('file').addEventListener('change',e=>document.getElementById(e.target.value).scrollIntoView({behavior:'instant',block:'start'}));
document.addEventListener('keydown',e=>{if(e.target.tagName==='SELECT')return;
 if(e.key==='ArrowRight')show(current+1);if(e.key==='ArrowLeft')show(current-1);});
document.querySelectorAll('.note').forEach(n=>n.addEventListener('click',()=>show(Number(n.dataset.step))));
if(steps.length){show(0);document.querySelector('main').scrollTop=0;}
</script></body></html>"""


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("base")
    p.add_argument("head")
    p.add_argument("comments", help="JSON file: [[path, start, end, text], ...] in walkthrough order")
    p.add_argument("-o", "--output", default="walkthrough.html")
    p.add_argument("--repo", default=".")
    p.add_argument("--title", default="")
    a = p.parse_args()
    print(render_walkthrough(a.repo, a.base, a.head, json.loads(Path(a.comments).read_text()), a.output, a.title))


if __name__ == "__main__":
    main()
