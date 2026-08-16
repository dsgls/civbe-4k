#!/usr/bin/env python3
"""Acceptance checks: a patched install vs the pristine reference trees.

The value oracle here is independent of the tool: a coordinate list is split on
its separators and each component multiplied as an integer.

    verify_ui_sweep.py                     # live install, scale 2, every tree
    verify_ui_sweep.py <game-dir> 2        # another install
    verify_ui_sweep.py --tree base 2       # one tree only
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paths import GAME, STOCK_TREES, TOOL
import collections, pathlib, re

sys.path.insert(0, TOOL)
from civbe_uiscale import styles as style_reader
from civbe_uiscale.classify import Space, classify
from civbe_uiscale.xmlpatch import _ATTR, iter_tags

failures = []


def check(ok, message):
    if not ok:
        failures.append(message)


def expected(value, scale):
    """Independent oracle: scale each component of a separator-delimited list,
    keeping the surrounding whitespace exactly as authored."""
    parts = re.split(r"([,.])", value)
    out = []
    for i, p in enumerate(parts):
        if i % 2:
            out.append(p)
            continue
        m = re.fullmatch(r"(\s*)(-?\d+)(\s*)", p)
        if not m:
            return None
        out.append(m.group(1) + str(int(m.group(2)) * scale) + m.group(3))
    return "".join(out)


def read(path):
    return open(path, encoding="utf-8", errors="replace").read()


def sequence(text, table):
    """Every live attribute in document order, with the element's effective
    attributes -- its own over its style's, the way the sweep classifies."""
    items = []
    for element, s, e, _depth in iter_tags(text):
        found = list(_ATTR.finditer(text, s, e))
        attrs = {m.group(1): m.group(2) for m in found}
        inherited = table.get(attrs.get("Style"))
        effective = {**inherited, **attrs} if inherited else attrs
        for m in found:
            items.append((element, m.group(1), m.group(2), effective,
                          text.count("\n", 0, m.start(2)) + 1))
    return items


def structural(pristine, patched):
    """Nothing but the bytes inside attribute quotes may move."""
    line_mismatch, bom_mismatch, files = [], [], 0
    for dp, dn, fn in os.walk(pristine):
        for f in fn:
            src = os.path.join(dp, f)
            rel = os.path.relpath(src, pristine)
            dst = os.path.join(patched, rel)
            if not os.path.exists(dst):
                failures.append("MISSING in patched tree: " + rel)
                continue
            a, b = open(src, "rb").read(), open(dst, "rb").read()
            if a.startswith(b"\xef\xbb\xbf") != b.startswith(b"\xef\xbb\xbf"):
                bom_mismatch.append(rel)
            # IconSupport.lua legitimately gains the icon-size pin line
            if a.count(b"\n") != b.count(b"\n") and f != "IconSupport.lua":
                line_mismatch.append(rel)
            files += 1
    check(not line_mismatch, "line count changed in: %s" % line_mismatch[:5])
    check(not bom_mismatch, "BOM changed in: %s" % bom_mismatch[:5])
    return files


def attributes(pristine, patched, scale, table):
    checked = collections.Counter()
    wrong, frozen_violations = [], []

    for dp, dn, fn in os.walk(pristine):
        for f in fn:
            if not f.lower().endswith(".xml"):
                continue
            rel = os.path.relpath(os.path.join(dp, f), pristine)
            dst = os.path.join(patched, rel)
            if not os.path.exists(dst):
                continue

            before = sequence(read(os.path.join(dp, f)), table)
            after = sequence(read(dst), table)
            if len(before) != len(after):
                failures.append("attribute count changed in %s: %d -> %d"
                                % (rel, len(before), len(after)))
                continue

            for (element, attr, old, attrs, line_no), (el2, at2, got, _, _) in zip(before, after):
                if (element, attr) != (el2, at2):
                    failures.append("attribute order changed in %s at line %d"
                                    % (rel, line_no))
                    break
                space = classify(element, attr, attrs)
                if space is Space.SCREEN:
                    want = expected(old, scale)
                    checked["screen"] += 1
                    if want is not None and got != want:
                        wrong.append((rel, line_no, element, attr, old, got, want))
                else:
                    checked[space.value] += 1
                    if got != old:
                        frozen_violations.append((rel, line_no, element, attr, old, got))

    check(not wrong, "screen-space values scaled incorrectly: %s" % wrong[:6])
    check(not frozen_violations, "non-screen values moved: %s" % frozen_violations[:6])
    return checked


def spot_checks(pristine, patched, scale):
    """A few end-to-end assertions per tree, on the files that have them."""
    def both(rel):
        return os.path.join(pristine, rel), os.path.join(patched, rel)

    stock, live = both("FontIcons/FontIcons.xml")
    if os.path.exists(stock):
        check(open(stock, "rb").read() == open(live, "rb").read(),
              "FontIcons.xml changed at texture-scale=1")

    stock, live = both("Styles.xml")
    if os.path.exists(stock):
        was = re.search(r'<FontNormal14 [^>]*FontSize="(\d+)"', read(stock))
        want = '<FontNormal14 Font="n023014t.ttf" FontSize="%d"/>' % (int(was.group(1)) * scale)
        text = read(live)
        check(want in text, "font not scaled (expected %s)" % want)
        check('StepSize="200,0"' in text, "AIAnim StepSize should stay frozen")
        check('<AIAnim Size="200,200"' in text, "AIAnim cell size should stay frozen")

    stock, live = both("IconSupport.lua")
    if os.path.exists(stock):
        text = read(live)
        check("iconSize * 1" in text, "icon size pin missing")
        check("atlas[iconSize]" in text, "atlas database key must not change")


def style_table(pristine, base_styles):
    """The styles a tree's controls resolve against: its own over the base
    tree's, since a DLC control can name a style the expansion never redefines.
    """
    raw = style_reader.collect(pathlib.Path(pristine))
    return style_reader.flatten({**base_styles, **raw})


def verify(name, pristine, patched, scale, base_styles):
    print("--- %s" % name)
    if not os.path.isdir(patched):
        failures.append("%s: no patched tree at %s" % (name, patched))
        return

    print("compared %d files" % structural(pristine, patched))
    checked = attributes(pristine, patched, scale, style_table(pristine, base_styles))
    print("verified %d screen-space, %d texture-space, %d untouched attributes"
          % (checked["screen"], checked["texture"], checked["none"]))
    spot_checks(pristine, patched, scale)


def main(argv):
    trees = list(STOCK_TREES)
    if "--tree" in argv:
        at = argv.index("--tree")
        trees = [argv[at + 1]]
        del argv[at:at + 2]
    game = argv[1] if len(argv) > 1 else GAME
    scale = int(argv[2]) if len(argv) > 2 else 2

    base_styles = style_reader.collect(pathlib.Path(STOCK_TREES["base"][0]))
    for name in trees:
        pristine, rel = STOCK_TREES[name]
        verify(name, pristine, os.path.join(game, *rel), scale, base_styles)

    print()
    if failures:
        print("FAILURES (%d):" % len(failures))
        for f in failures:
            print("  -", f)
        return 1
    print("ALL ACCEPTANCE CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
