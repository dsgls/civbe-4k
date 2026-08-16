"""The named styles a control inherits from.

`Style="NextButtonFlag"` pulls in that style's attributes, and those attributes
are what decide how the control's own `Size` is read: a 9-sliced style stretches
its texture, an atlas style makes `Size` a source rect. Classification is wrong
without them -- the End Turn button carries its slicing entirely in its style,
so `Size` reads as texture space and the button stays 45px tall at 2x.

Styles live in the `<StyleSheet>` files of the tree (`Styles.xml`,
`Debug/CoreStyles.xml`, ...), one definition per depth-1 tag, and a definition
may name another style itself.
"""
from .xmlpatch import attrs_of, iter_tags

STYLE_SHEET_ROOT = "StyleSheet"


def parse(text: str) -> dict:
    """Style name -> its own attributes. Empty for a non-stylesheet file."""
    table = {}
    root_seen = False
    for element, body_start, body_end, depth in iter_tags(text):
        if depth == 0:
            if element != STYLE_SHEET_ROOT:
                return {}
            root_seen = True
        elif depth == 1 and root_seen:
            table[element] = attrs_of(text, body_start, body_end)
    return table


def collect(source_dir) -> dict:
    """Merge every stylesheet in a tree. Later files win, as the engine does."""
    table = {}
    for path in sorted(source_dir.rglob("*.xml")):
        if not path.is_file():
            continue
        data = path.read_bytes()
        if b"<" + STYLE_SHEET_ROOT.encode() not in data:
            continue
        table.update(parse(data.decode("utf-8", "surrogateescape")))
    return table


def flatten(table: dict) -> dict:
    """Resolve each style's own `Style=` chain into one attribute map.

    Merge order follows the engine: what the style writes itself beats what it
    inherits. A cycle stops rather than recursing.
    """
    resolved = {}

    def resolve(name, seen):
        if name in resolved:
            return resolved[name]
        own = table.get(name)
        if own is None:
            return {}
        parent = own.get("Style")
        merged = own
        if parent and parent not in seen:
            merged = {**resolve(parent, seen | {name}), **own}
        resolved[name] = merged
        return merged

    for name in table:
        resolve(name, frozenset())
    return resolved
