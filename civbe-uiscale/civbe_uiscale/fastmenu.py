"""Optional front-end tweaks: no menu fade-in, no legal screen.

The main menu stages every entry behind a slide and a fade on a growing
`Pause`, so the last one lands 1.5s after the menu appears, and the front end
queues a legal disclaimer over it on every launch. None of this is geometry, so
the pass is independent of the scale and runs on top of the scaled output.

Both edits are re-derived from the pristine backup like everything else, so
dropping `--fast-menu` from a later run puts the stock animation back.
"""
import re
from dataclasses import dataclass

from .classify import Space

MAIN_MENU = "frontend/mainmenu.xml"
FRONT_END_LUA = "frontend/frontend.lua"

# `Start` is where a SlideAnim travels from; zeroing it against the stock
# `End="0,0"` leaves the entry in its final place. Matched inside the tag so
# AlphaStart, SliceStart and the 9-grid *TexStart attributes are left alone.
_SLIDE_START = re.compile(r'(<SlideAnim\b[^>]*?)(?<![A-Za-z])Start="([^"]*)"')

# An entry starting at full alpha is visible from the first frame, whatever
# `Pause` the animation carries.
_ALPHA_START = re.compile(r'AlphaStart="0"')

_LEGAL_POPUP = re.compile(
    r'^([ \t]*)(?!--)(UIManager:QueuePopup\(\s*Controls\.LegalScreen\b[^\n]*)$',
    re.M,
)


@dataclass(frozen=True)
class FastMenuChange:
    line: int
    element: str
    attr: str
    space: Space
    old: str
    new: str


def _line_of(text, index):
    return text.count("\n", 0, index) + 1


def patch_main_menu(text: str):
    """Zero the slide offsets and open every entry at full alpha."""
    changes = []

    def slide(m):
        if m.group(2) == "0,0":
            return m.group(0)
        changes.append(FastMenuChange(
            line=_line_of(text, m.start()), element="SlideAnim", attr="Start",
            space=Space.NONE, old=m.group(2), new="0,0",
        ))
        return '%sStart="0,0"' % m.group(1)

    def alpha(m):
        changes.append(FastMenuChange(
            line=_line_of(text, m.start()), element="AlphaAnim", attr="AlphaStart",
            space=Space.NONE, old="0", new="1",
        ))
        return 'AlphaStart="1"'

    # Alpha first: it is a same-length substitution, so the offsets the slide
    # pass reports still line up with the original text.
    patched = _ALPHA_START.sub(alpha, text)
    patched = _SLIDE_START.sub(slide, patched)
    return patched, changes


def patch_front_end_lua(text: str):
    """Comment out the legal disclaimer popup."""
    changes = []

    def comment(m):
        changes.append(FastMenuChange(
            line=_line_of(text, m.start()), element="QueuePopup",
            attr="LegalScreen", space=Space.NONE,
            old=m.group(2), new="-- " + m.group(2),
        ))
        return "%s-- %s" % (m.group(1), m.group(2))

    return _LEGAL_POPUP.sub(comment, text), changes


def patch(rel_posix: str, text: str):
    """Apply whichever front-end tweak `rel_posix` calls for, if any."""
    lowered = rel_posix.lower()
    if lowered == MAIN_MENU:
        return patch_main_menu(text)
    if lowered == FRONT_END_LUA:
        return patch_front_end_lua(text)
    return text, []
