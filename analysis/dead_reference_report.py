#!/usr/bin/env python3
"""Where is each dead texture reference made, and is that reference live?"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paths import GAME, STOCK_UI, EXTRACTED, TOOL, TEXTURE_LIST, ATLAS_DBS
import os, re, sys, collections

sys.path.insert(0, TOOL)
from civbe_uiscale.xmlpatch import _ATTR, _iter_tags

PRISTINE = STOCK_UI
DBS = ATLAS_DBS
DEAD = [l.strip().lower() for l in
        open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "dead.txt"))
        if l.strip()]

sites = collections.defaultdict(list)


def base(ref):
    return ref.strip().replace("\\", "/").rsplit("/", 1)[-1].lower()


# live XML references (the tag scanner already skips comments)
for dp, dn, fn in os.walk(PRISTINE):
    for f in fn:
        if not f.lower().endswith(".xml"):
            continue
        rel = os.path.relpath(os.path.join(dp, f), PRISTINE).replace("\\", "/")
        text = open(os.path.join(dp, f), encoding="utf-8", errors="replace").read()
        live = set()
        for element, s, e in _iter_tags(text):
            for m in _ATTR.finditer(text, s, e):
                if m.group(1) in ("Texture", "MaskTexture", "ButtonTexture"):
                    live.add(base(m.group(2)))
        # every occurrence, including commented-out ones
        allrefs = set(base(m.group(2)) for m in _ATTR.finditer(text)
                      if m.group(1) in ("Texture", "MaskTexture", "ButtonTexture"))
        for name in DEAD:
            if name in live:
                sites[name].append(("live XML", rel))
            elif name in allrefs:
                sites[name].append(("commented-out XML", rel))

# atlas database rows
for path in DBS:
    if not os.path.exists(path):
        continue
    rel = os.path.relpath(path, GAME).replace("\\", "/")
    text = open(path, encoding="utf-8", errors="replace").read()
    for row in re.finditer(r"<Row>(.*?)</Row>", text, re.S):
        m = re.search(r"<Filename>(.*?)</Filename>", row.group(1), re.S)
        if m and base(m.group(1)) in DEAD:
            atlas = re.search(r"<Atlas>(.*?)</Atlas>", row.group(1), re.S)
            size = re.search(r"<IconSize>(.*?)</IconSize>", row.group(1), re.S)
            sites[base(m.group(1))].append(
                ("atlas DB row (%s size %s)" % (atlas.group(1) if atlas else "?",
                                                size.group(1) if size else "?"), rel))

# lua
for dp, dn, fn in os.walk(PRISTINE):
    for f in fn:
        if not f.lower().endswith(".lua"):
            continue
        rel = os.path.relpath(os.path.join(dp, f), PRISTINE).replace("\\", "/")
        text = open(os.path.join(dp, f), encoding="utf-8", errors="replace").read()
        for m in re.finditer(r'"([^"]+\.dds)"', text, re.I):
            if base(m.group(1)) in DEAD:
                sites[base(m.group(1))].append(("Lua", rel))

kinds = collections.Counter()
print("%-44s %s" % ("dead reference", "referenced from"))
for name in DEAD:
    where = sites.get(name, [])
    labels = sorted(set(w[0].split(" (")[0] for w in where))
    kinds[",".join(labels) or "NOT FOUND"] += 1
    first = where[0] if where else ("?", "?")
    print("%-44s %-26s %s" % (name, first[0], first[1]))

print()
print("by reference kind:", dict(kinds))
