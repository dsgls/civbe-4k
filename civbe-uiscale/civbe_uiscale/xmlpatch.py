"""In-place rewriting of UI XML attribute values.

The file is treated as text with known spans rather than as a parsed document:
the engine's XML is hand-formatted and a serialising parser would reflow every
line, burying the real changes. Only the bytes inside a matched attribute's
quotes are replaced.
"""
import re
from dataclasses import dataclass

from .classify import Space, classify
from .values import scale_value_checked

_ATTR = re.compile(r'([A-Za-z_][\w-]*)\s*=\s*"([^"]*)"')
_NAME = re.compile(r'[A-Za-z_][\w.-]*')


@dataclass(frozen=True)
class Change:
    line: int
    element: str
    attr: str
    space: Space
    old: str
    new: str


def _skip_to(text: str, start: int, terminator: str) -> int:
    end = text.find(terminator, start)
    return len(text) if end < 0 else end + len(terminator)


def _end_of_tag(text: str, start: int) -> int:
    """Index just past the '>' closing the tag, tolerating '>' inside values."""
    i = start
    while i < len(text):
        ch = text[i]
        if ch == '"':
            close = text.find('"', i + 1)
            i = len(text) if close < 0 else close + 1
        elif ch == ">":
            return i + 1
        else:
            i += 1
    return len(text)


def _iter_tags(text: str):
    """Yield (element_name, body_start, body_end) for each opening tag, skipping
    comments, CDATA sections, processing instructions and closing tags."""
    i = 0
    n = len(text)
    while i < n:
        lt = text.find("<", i)
        if lt < 0:
            return
        if text.startswith("<!--", lt):
            i = _skip_to(text, lt, "-->")
            continue
        if text.startswith("<![CDATA[", lt):
            i = _skip_to(text, lt, "]]>")
            continue
        if text.startswith("<?", lt) or text.startswith("<!", lt):
            i = _skip_to(text, lt, ">")
            continue
        if text.startswith("</", lt):
            i = _skip_to(text, lt, ">")
            continue
        m = _NAME.match(text, lt + 1)
        if not m:
            i = lt + 1
            continue
        end = _end_of_tag(text, m.end())
        yield m.group(0), m.end(), end - 1
        i = end


def patch_xml(text: str, ui_scale: float, texture_scale: float):
    """Return the rewritten text and the list of changes made."""
    scales = {Space.SCREEN: ui_scale, Space.TEXTURE: texture_scale}
    edits = []
    changes = []

    for element, body_start, body_end in _iter_tags(text):
        found = list(_ATTR.finditer(text, body_start, body_end))
        attrs = {m.group(1): m.group(2) for m in found}
        for m in found:
            attr, old = m.group(1), m.group(2)
            space = classify(element, attr, attrs)
            scale = scales.get(space)
            if scale is None:
                continue
            new, changed = scale_value_checked(old, scale)
            if not changed:
                continue
            edits.append((m.start(2), m.end(2), new))
            changes.append(Change(
                line=text.count("\n", 0, m.start(2)) + 1,
                element=element, attr=attr, space=space, old=old, new=new,
            ))

    if not edits:
        return text, changes

    out = []
    cursor = 0
    for start, end, new in edits:
        out.append(text[cursor:start])
        out.append(new)
        cursor = end
    out.append(text[cursor:])
    return "".join(out), changes
