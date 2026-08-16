"""Coordinate-space classification for UI XML attributes.

Deny by default: an attribute counts as geometry only if it is named here. The
inventory comes from a sweep of every attribute in the stock Assets/UI tree.
This is the classifier the 2x bake of ui/ was generated and verified with; it
now drives the ui_textures.txt derivation.
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
_TRAVEL_MARKERS = ("Start", "End", "Cycle")

_ATLAS_MARKERS = ("TextureOffset", "StateOffsetIncrement")
_STRETCH_MARKERS = ("SliceCorner", "SliceSize", "SliceTextureSize", "SliceStart")


def _stretches(attrs) -> bool:
    """True when the texture is stretched to fit rather than sampled at 1:1.
    Both spellings count: the four Slice* attributes, and the per-piece form
    (`CSize`, `ULTexStart`, ...) that most of the game's 9-grids use."""
    return (any(marker in attrs for marker in _STRETCH_MARKERS)
            or not NINE_GRID_ATTRS.isdisjoint(attrs))


def _samples_a_sub_rect(attrs) -> bool:
    """True when the control reads a sub-rect of an atlas, making its Size the
    source rect. A 9-sliced control stretches its texture instead, so slicing
    takes precedence over the atlas markers."""
    if _stretches(attrs):
        return False
    return any(marker in attrs for marker in _ATLAS_MARKERS)


def _travels(attrs) -> bool:
    """True for an animation that moves a control across the screen. The engine
    element is <SlideAnim>, but a slide can also be defined as a named style,
    and then the element name is the style's -- so match the shape instead."""
    return all(marker in attrs for marker in _TRAVEL_MARKERS)


def classify(element: str, attr: str, attrs) -> Space:
    """Return the coordinate space of `attr` on `element`.

    `attrs` is the element's effective attributes -- its own, over those it
    inherits from its `Style` -- needed because Size is only a source rect in
    the company of atlas coordinates, and those often live in the style.
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
        if element in _SCREEN_GEOMETRY_ELEMENTS or _travels(attrs):
            return Space.SCREEN
        return Space.NONE

    if attr in SCREEN_ATTRS:
        return Space.SCREEN

    return Space.NONE
