"""Compare mode: run every upscaler over every input and write `index.html`.

`run_compare` is the whole entry point cli.py calls into. It writes
`<inputname>-<upscaler>.png` for every input x upscaler pair, copies each
source PNG into the output dir for the HTML's two reference cells, and
writes a self-contained `index.html` that lays every input's variants out
side by side at in-game size.
"""

from __future__ import annotations

import html
import shutil
from pathlib import Path

from PIL import Image

from .apply import apply_upscalers

#: (label, is_nearest) for the two reference cells that lead every row,
#: rendered straight from the source PNG -- no extra files, no upscaler.
_REFERENCE_CELLS = (("original, 2x nearest", True), ("original, 2x smooth", False))


def run_compare(
    input_files: list[Path],
    output_dir: Path,
    upscaler_names: list[str],
    crops: dict[str, list[tuple[int, int, int, int]]],
) -> int:
    """Upscale every input with every upscaler and write the comparison HTML.

    `crops` is keyed by input filename (`Path.name`), matching how cli.py's
    `--crop <file>=<x,y,w,h>` is parsed and grouped. A crop key that matches
    no input is an error rather than a silently-ignored typo, consistent
    with the tool's "nothing is skipped silently" rule.
    """
    unmatched = set(crops) - {p.name for p in input_files}
    if unmatched:
        raise SystemExit(f"--crop file(s) not among inputs: {', '.join(sorted(unmatched))}")

    output_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    for p in input_files:
        with Image.open(p) as img:
            img.load()
            orig_w, orig_h = img.size
            variants = [
                (name, out_img) for name, out_img in apply_upscalers(upscaler_names, img)
            ]

        ref_name = p.name
        shutil.copyfile(p, output_dir / ref_name)

        variant_files = []
        for name, out_img in variants:
            fname = f"{p.stem}-{name}.png"
            out_img.save(output_dir / fname)
            variant_files.append((name, fname))

        rows.append(_Row(p.name, orig_w, orig_h, ref_name, variant_files, crops.get(p.name, [])))

    (output_dir / "index.html").write_text(_render_html(rows), encoding="utf-8")
    return 0


class _Row:
    def __init__(
        self,
        input_name: str,
        orig_w: int,
        orig_h: int,
        ref_name: str,
        variant_files: list[tuple[str, str]],
        crop_rects: list[tuple[int, int, int, int]],
    ) -> None:
        self.input_name = input_name
        self.orig_w = orig_w
        self.orig_h = orig_h
        self.ref_name = ref_name
        self.variant_files = variant_files
        self.crop_rects = crop_rects


# --------------------------------------------------------------------------
# HTML rendering
# --------------------------------------------------------------------------


def _cell(
    label: str,
    src: str,
    orig_w: int,
    orig_h: int,
    *,
    nearest: bool = False,
    crop: tuple[int, int, int, int] | None = None,
) -> str:
    """One labelled image cell.

    Every image's displayed size is `2*orig / devicePixelRatio` (in-game
    size, see `_SCRIPT`), regardless of whether `src` is an already-2x
    upscaler output or the 1x source PNG being stretched for a reference
    cell -- both are sized in the same coordinate space so they line up.
    `data-w`/`data-h` on the `<img>` hold that 2x pixel size; `data-cw` etc.
    on the wrapper hold the (possibly cropped) window into it, all in the
    same 2x space so a crop is just a sub-rect scaled the same way.
    """
    w2, h2 = orig_w * 2, orig_h * 2
    if crop is None:
        cw, ch, cx, cy = w2, h2, 0, 0
    else:
        x, y, w, h = crop
        cw, ch, cx, cy = w * 2, h * 2, x * 2, y * 2
    img_class = ' class="nearest"' if nearest else ""
    return (
        '<div class="cell">'
        f'<div class="label">{html.escape(label)}</div>'
        f'<div class="imgwrap" data-cw="{cw}" data-ch="{ch}" data-cx="{cx}" data-cy="{cy}">'
        f'<img src="{html.escape(src)}" data-w="{w2}" data-h="{h2}"'
        f'{img_class} loading="lazy" alt="{html.escape(label)}">'
        "</div></div>"
    )


def _variant_cells(
    row: "_Row", crop: tuple[int, int, int, int] | None
) -> str:
    cells = [
        _cell(label, row.ref_name, row.orig_w, row.orig_h, nearest=nearest, crop=crop)
        for label, nearest in _REFERENCE_CELLS
    ]
    cells += [
        _cell(name, fname, row.orig_w, row.orig_h, crop=crop) for name, fname in row.variant_files
    ]
    return "".join(cells)


def _render_row(row: "_Row") -> str:
    parts = [
        f'<section class="input-row">',
        f'<h2>{html.escape(row.input_name)} '
        f'<span class="dims">{row.orig_w}x{row.orig_h}</span></h2>',
        f'<div class="variants">{_variant_cells(row, None)}</div>',
    ]
    for x, y, w, h in row.crop_rects:
        parts.append(
            f'<div class="variants crop-row" title="crop {x},{y} {w}x{h}">'
            f"{_variant_cells(row, (x, y, w, h))}</div>"
        )
    parts.append("</section>")
    return "\n".join(parts)


_STYLE = """
:root { color-scheme: dark; }
* { box-sizing: border-box; }
body {
  margin: 0;
  font-family: system-ui, sans-serif;
  background: #14141a;
  color: #ddd;
}
.toolbar {
  position: sticky;
  top: 0;
  z-index: 10;
  display: flex;
  align-items: center;
  gap: 0.5em;
  padding: 0.5em 1em;
  background: #1e1e26;
  border-bottom: 1px solid #333;
}
.toolbar button {
  padding: 0.3em 0.8em;
  background: #2a2a33;
  color: #ddd;
  border: 1px solid #444;
  border-radius: 4px;
  cursor: pointer;
}
.toolbar button.active {
  background: #4a6fa5;
  border-color: #6a8fc5;
  color: #fff;
}
.input-row {
  padding: 1em;
  border-bottom: 1px solid #2a2a33;
}
.input-row h2 {
  font-size: 1em;
  font-weight: 600;
  margin: 0 0 0.5em 0;
}
.input-row h2 .dims {
  font-weight: 400;
  color: #999;
}
.variants {
  display: flex;
  flex-wrap: nowrap;
  overflow-x: auto;
  gap: 1em;
  padding-bottom: 0.5em;
}
.variants.crop-row {
  margin-top: 0.5em;
}
.cell {
  flex: 0 0 auto;
}
.cell .label {
  font-size: 0.8em;
  color: #aaa;
  margin-bottom: 0.25em;
  white-space: nowrap;
}
.imgwrap {
  position: relative;
  overflow: hidden;
}
.imgwrap img {
  position: absolute;
  left: 0;
  top: 0;
}
.imgwrap img.nearest { image-rendering: pixelated; }

body.bg-checkerboard .imgwrap {
  background-color: #ccc;
  background-image:
    linear-gradient(45deg, #808080 25%, transparent 25%),
    linear-gradient(-45deg, #808080 25%, transparent 25%),
    linear-gradient(45deg, transparent 75%, #808080 75%),
    linear-gradient(-45deg, transparent 75%, #808080 75%);
  background-size: 16px 16px;
  background-position: 0 0, 0 8px, 8px -8px, -8px 0px;
}
body.bg-black .imgwrap { background: #000; }
body.bg-white .imgwrap { background: #fff; }
body.bg-darkblue .imgwrap { background: #1b2838; }
"""

# Re-run on load and on resize: Windows display scaling changes
# `devicePixelRatio` without a page reload, and without recomputing CSS size
# from it every variant gets resampled with smooth filtering by the browser,
# which is exactly the artifact this sizing exists to avoid judging.
_SCRIPT = """
function updateSizes() {
  const dpr = window.devicePixelRatio || 1;
  document.querySelectorAll('.imgwrap').forEach(function (wrap) {
    const cw = +wrap.dataset.cw, ch = +wrap.dataset.ch;
    const cx = +wrap.dataset.cx, cy = +wrap.dataset.cy;
    wrap.style.width = (cw / dpr) + 'px';
    wrap.style.height = (ch / dpr) + 'px';
    const img = wrap.querySelector('img');
    const w = +img.dataset.w, h = +img.dataset.h;
    img.style.width = (w / dpr) + 'px';
    img.style.height = (h / dpr) + 'px';
    img.style.left = (-cx / dpr) + 'px';
    img.style.top = (-cy / dpr) + 'px';
  });
}
window.addEventListener('load', updateSizes);
window.addEventListener('resize', updateSizes);

document.querySelectorAll('.toolbar button').forEach(function (btn) {
  btn.addEventListener('click', function () {
    document.body.className = 'bg-' + btn.dataset.bg;
    document.querySelectorAll('.toolbar button').forEach(function (b) {
      b.classList.toggle('active', b === btn);
    });
  });
});
"""

_BACKGROUNDS = (
    ("checkerboard", "Checkerboard"),
    ("black", "Black"),
    ("white", "White"),
    ("darkblue", "Dark blue"),
)


def _render_html(rows: list["_Row"]) -> str:
    toolbar_buttons = "".join(
        f'<button data-bg="{bg}"{" class=\"active\"" if bg == "darkblue" else ""}>'
        f"{html.escape(label)}</button>"
        for bg, label in _BACKGROUNDS
    )
    body_rows = "\n".join(_render_row(row) for row in rows)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>civbe-upscale comparison</title>
<style>{_STYLE}</style>
</head>
<body class="bg-darkblue">
<div class="toolbar">
<span>Background:</span>
{toolbar_buttons}
</div>
{body_rows}
<script>{_SCRIPT}</script>
</body>
</html>
"""
