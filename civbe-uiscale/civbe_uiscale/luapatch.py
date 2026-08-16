"""Rewriting hardcoded layout calls in the UI Lua.

Only all-literal calls are rewritten. A call like
`SetOffsetVal(12, parentSizeY - 20)` is left alone: its computed half already
derives from controls the XML pass has scaled, so scaling the literal too
would double-count.
"""
import re
from dataclasses import dataclass

from .classify import Space
from .values import scale_value_checked

SCREEN_SETTERS = (
    "SetSizeVal", "SetOffsetVal", "SetSizeX", "SetSizeY",
    "SetOffsetX", "SetOffsetY", "SetWrapWidth", "SetFontSize",
    # A SlideAnim's travel, set from Lua: the counterpart of the XML
    # Start/End that classify.py already scales.
    "SetBeginVal", "SetEndVal",
)
TEXTURE_SETTERS = ("SetTextureOffsetVal", "SetTextureSizeVal")

_NUMBER = r"-?\d+(?:\.\d+)?"
_ARGS = r"(?P<args>\s*%s\s*(?:,\s*%s\s*)*)" % (_NUMBER, _NUMBER)


def _call_pattern(names):
    # (?<!\w) keeps `MySetSizeY` from matching while still allowing the `:` and
    # `.` of an ordinary Lua method call.
    return re.compile(r"(?<!\w)(?P<name>%s)\s*\(%s\)" % ("|".join(names), _ARGS))


_SCREEN_CALLS = _call_pattern(SCREEN_SETTERS)
_TEXTURE_CALLS = _call_pattern(TEXTURE_SETTERS)

_COMMENT = re.compile(r"--\[(?P<eq>=*)\[.*?\](?P=eq)\]|--[^\n]*", re.S)


@dataclass(frozen=True)
class LuaChange:
    line: int
    call: str
    space: Space
    old: str
    new: str


def _comment_spans(text):
    return [(m.start(), m.end()) for m in _COMMENT.finditer(text)]


def _inside(spans, index):
    return any(start <= index < end for start, end in spans)


def patch_lua(text: str, ui_scale: float, texture_scale: float):
    """Return the rewritten Lua and the list of changes made."""
    spans = _comment_spans(text)
    edits = []
    changes = []

    for pattern, space, scale in (
        (_SCREEN_CALLS, Space.SCREEN, ui_scale),
        (_TEXTURE_CALLS, Space.TEXTURE, texture_scale),
    ):
        for m in pattern.finditer(text):
            if _inside(spans, m.start()):
                continue
            old = m.group("args")
            parts = re.split(r"(,)", old)
            new_parts = []
            changed_any = False
            for index, part in enumerate(parts):
                if index % 2:
                    new_parts.append(part)
                    continue
                scaled, changed = scale_value_checked(part, scale)
                new_parts.append(scaled)
                changed_any = changed_any or changed
            if not changed_any:
                continue
            new = "".join(new_parts)
            edits.append((m.start("args"), m.end("args"), new))
            changes.append(LuaChange(
                line=text.count("\n", 0, m.start()) + 1,
                call=m.group("name"), space=space, old=old, new=new,
            ))

    if not edits:
        return text, changes

    edits.sort()
    out = []
    cursor = 0
    for start, end, new in edits:
        out.append(text[cursor:start])
        out.append(new)
        cursor = end
    out.append(text[cursor:])
    return "".join(out), changes


# --- IconSupport.lua ---------------------------------------------------------
#
# Atlas icons get their TextureOffset at runtime, computed as
# cell_index * iconSize. iconSize is the IconTextureAtlases database key, so it
# must keep its stock value; only the pixel arithmetic is rescaled. Pinning the
# control size to one cell keeps runtime-hooked icons sampling exactly one icon
# whatever the XML says.

_OFFSET_EXPRESSIONS = (
    "(offset % numCols) * iconSize",
    "math.floor(offset / numCols) * iconSize",
)
_HOOKUP_CALL = "imageControl:SetTextureOffsetVal("
_MARKER = "--[[ civbe-uiscale ]]"


def _format_scale(scale: float) -> str:
    return str(int(scale)) if float(scale).is_integer() else repr(float(scale))


def patch_icon_support(text: str, texture_scale: float, pin_icon_size: bool = False):
    """Rescale the atlas offset arithmetic in IconSupport.lua.

    Returns the rewritten text and the number of substitutions made.
    """
    if _MARKER in text:
        return text, 0

    factor = _format_scale(texture_scale)
    count = 0

    for expression in _OFFSET_EXPRESSIONS:
        replacement = "%s * %s" % (expression, factor)
        occurrences = text.count(expression)
        if occurrences:
            text = text.replace(expression, replacement)
            count += occurrences

    if pin_icon_size:
        index = text.find(_HOOKUP_CALL)
        if index >= 0:
            line_start = text.rfind("\n", 0, index) + 1
            indent = text[line_start:index]
            line_end = text.find("\n", index)
            line_end = len(text) if line_end < 0 else line_end + 1
            pin = "%simageControl:SetSizeVal( iconSize * %s, iconSize * %s );%s\n" % (
                indent, factor, factor, _MARKER,
            )
            text = text[:line_end] + pin + text[line_end:]
            count += 1

    return text, count
