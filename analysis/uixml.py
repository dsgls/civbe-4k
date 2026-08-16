"""Minimal parsing of the game's hand-formatted UI XML.

The files are treated as text with known spans rather than as a parsed
document: a serialising parser would reflow every line. `iter_tags` yields the
attribute-body span of each opening tag; `ATTR` matches the attributes inside
such a span.
"""
import re

ATTR = re.compile(r'([A-Za-z_][\w-]*)\s*=\s*"([^"]*)"')
_NAME = re.compile(r'[A-Za-z_][\w.-]*')


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


def iter_tags(text: str):
    """Yield (element_name, body_start, body_end, depth) for each opening tag,
    skipping comments, CDATA sections, processing instructions and closing
    tags. The root sits at depth 0, so a stylesheet's style definitions are its
    depth-1 tags."""
    i = 0
    n = len(text)
    depth = 0
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
            depth -= 1
            i = _skip_to(text, lt, ">")
            continue
        m = _NAME.match(text, lt + 1)
        if not m:
            i = lt + 1
            continue
        end = _end_of_tag(text, m.end())
        yield m.group(0), m.end(), end - 1, depth
        if text[end - 2:end] != "/>":
            depth += 1
        i = end
