"""Coordinate-space classification for UI XML attributes.

Deny by default: an attribute is only rewritten if it is named here. The
inventory comes from a sweep of every attribute in the stock Assets/UI tree.
"""
import enum


class Space(enum.Enum):
    SCREEN = "screen"    # pixels on screen; scales with the UI
    TEXTURE = "texture"  # coordinates inside a .dds; scales only with the art
    NONE = "none"        # not geometry


SCREEN_ATTRS = frozenset({
    "Offset", "Padding", "WrapWidth", "LeadingOffset", "FontSize", "TextOffset",
    "TruncateWidth", "StackPadding", "SpaceForScroll", "ScrollThreshold",
    "ButtonSize", "CheckSize", "EndOffset", "Gutter", "SizePadding",
    "AutoSizePadding", "ReduceWidth", "Length",
})

TEXTURE_ATTRS = frozenset({
    "TextureOffset", "StateOffsetIncrement",
    "SliceCorner", "SliceSize", "SliceTextureSize", "SliceStart",
    "StepSize",
})

# 9-grid styles name each piece: <piece>Size is drawn at 1:1 from <piece>TexStart,
# so both live in texture space.
_NINE_GRID_PIECES = ("UL", "UC", "UR", "L", "C", "R", "LL", "LC", "LR")
NINE_GRID_ATTRS = frozenset(
    [p + "Size" for p in _NINE_GRID_PIECES] + [p + "TexStart" for p in _NINE_GRID_PIECES]
)

# Elements whose Size is a cell in a sprite sheet rather than a drawn box.
_SHEET_ELEMENTS = frozenset({"FlipAnim", "AIAnim"})

# <Icon> in FontIcons.xml: every attribute describes the glyph atlas.
_FONT_ICON_ATTRS = frozenset({"Start", "Size", "Advance", "Baseline"})

# Elements that travel across the screen or draw a primitive.
_SCREEN_GEOMETRY_ELEMENTS = frozenset({"SlideAnim", "NotificationSlide", "Line"})
_SCREEN_GEOMETRY_ATTRS = frozenset({"Start", "End", "Width"})

_ATLAS_MARKERS = ("TextureOffset", "StateOffsetIncrement")
_STRETCH_MARKERS = ("SliceCorner", "SliceSize", "SliceTextureSize", "SliceStart")


def _samples_a_sub_rect(attrs) -> bool:
    """True when the control reads a sub-rect of an atlas, making its Size the
    source rect. A 9-sliced control stretches its texture instead, so slicing
    takes precedence over the atlas markers."""
    if any(marker in attrs for marker in _STRETCH_MARKERS):
        return False
    return any(marker in attrs for marker in _ATLAS_MARKERS)


def classify(element: str, attr: str, attrs) -> Space:
    """Return the coordinate space of `attr` on `element`.

    `attrs` is the full attribute mapping of the element, needed because Size
    is only a source rect in the company of atlas coordinates.
    """
    if element == "Icon" and attr in _FONT_ICON_ATTRS:
        return Space.TEXTURE

    if attr in NINE_GRID_ATTRS or attr in TEXTURE_ATTRS:
        return Space.TEXTURE

    if attr == "Size":
        if element in _SHEET_ELEMENTS:
            return Space.TEXTURE
        return Space.TEXTURE if _samples_a_sub_rect(attrs) else Space.SCREEN

    if attr in _SCREEN_GEOMETRY_ATTRS:
        return Space.SCREEN if element in _SCREEN_GEOMETRY_ELEMENTS else Space.NONE

    if attr in SCREEN_ATTRS:
        return Space.SCREEN

    return Space.NONE
