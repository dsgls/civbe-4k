#!/usr/bin/env python3
"""Acceptance checks: patched scratch tree vs the pristine backup.

The value oracle here is independent of the tool: a coordinate list is split on
its separators and each component multiplied as an integer.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paths import GAME, STOCK_UI, EXTRACTED, TOOL, TEXTURE_LIST, ATLAS_DBS
import os, re, sys, collections

sys.path.insert(0, TOOL)
from civbe_uiscale.classify import Space, classify
from civbe_uiscale.xmlpatch import _ATTR, _iter_tags

PRISTINE = STOCK_UI
# The patched Assets/UI to check. Pass a path, or default to a live install.
PATCHED = sys.argv[1] if len(sys.argv) > 1 else os.path.join(GAME, "assets", "UI")
UI_SCALE = int(sys.argv[2]) if len(sys.argv) > 2 else 2

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

# ---------------------------------------------------------------- structural
line_mismatch, bom_mismatch, files = [], [], 0
for dp, dn, fn in os.walk(PRISTINE):
    for f in fn:
        src = os.path.join(dp, f)
        rel = os.path.relpath(src, PRISTINE)
        dst = os.path.join(PATCHED, rel)
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
print("compared %d files" % files)

# ------------------------------------------- per-attribute invariants (live code)
checked = collections.Counter()
wrong = []
frozen_violations = []

for dp, dn, fn in os.walk(PRISTINE):
    for f in fn:
        if not f.lower().endswith(".xml"):
            continue
        rel = os.path.relpath(os.path.join(dp, f), PRISTINE)
        dst = os.path.join(PATCHED, rel)
        if not os.path.exists(dst):
            continue
        a = open(os.path.join(dp, f), encoding="utf-8", errors="replace").read()
        b = open(dst, encoding="utf-8", errors="replace").read()

        def sequence(text):
            """Every live attribute in document order, with its element."""
            items = []
            for element, s, e in _iter_tags(text):
                found = list(_ATTR.finditer(text, s, e))
                attrs = {m.group(1): m.group(2) for m in found}
                for m in found:
                    items.append((element, m.group(1), m.group(2), attrs,
                                  text.count("\n", 0, m.start(2)) + 1))
            return items

        before, after = sequence(a), sequence(b)
        if len(before) != len(after):
            failures.append("attribute count changed in %s: %d -> %d"
                            % (rel, len(before), len(after)))
            continue

        for (element, attr, old, attrs, line_no), (el2, at2, got, _, _) in zip(before, after):
            if (element, attr) != (el2, at2):
                failures.append("attribute order changed in %s at line %d" % (rel, line_no))
                break
            space = classify(element, attr, attrs)
            if space is Space.SCREEN:
                want = expected(old, UI_SCALE)
                checked["screen"] += 1
                if want is not None and got != want:
                    wrong.append((rel, line_no, element, attr, old, got, want))
            else:
                checked[space.value] += 1
                if got != old:
                    frozen_violations.append((rel, line_no, element, attr, old, got))

check(not wrong, "screen-space values scaled incorrectly: %s" % wrong[:6])
check(not frozen_violations, "non-screen values moved: %s" % frozen_violations[:6])
print("verified %d screen-space, %d texture-space, %d untouched attributes"
      % (checked["screen"], checked["texture"], checked["none"]))

# ------------------------------------------------------------- FontIcons frozen
fi = "FontIcons/FontIcons.xml"
check(open(os.path.join(PRISTINE, fi), "rb").read() == open(os.path.join(PATCHED, fi), "rb").read(),
      "FontIcons.xml changed at texture-scale=1")

# ------------------------------------------------------------------ spot checks
styles = open(os.path.join(PATCHED, "Styles.xml"), encoding="utf-8", errors="replace").read()
check('<FontNormal14 Font="n023014t.ttf" FontSize="24"/>' in styles, "font not scaled")
check('StepSize="200,0"' in styles, "AIAnim StepSize should stay frozen")
check('<AIAnim Size="200,200"' in styles, "AIAnim cell size should stay frozen")

icon_support = open(os.path.join(PATCHED, "IconSupport.lua"), encoding="utf-8", errors="replace").read()
check("iconSize * 1" in icon_support, "icon size pin missing")
check("atlas[iconSize]" in icon_support, "atlas database key must not change")

print()
if failures:
    print("FAILURES (%d):" % len(failures))
    for f in failures:
        print("  -", f)
    sys.exit(1)
print("ALL ACCEPTANCE CHECKS PASSED")
