"""Parsing and scaling of Beyond Earth UI coordinate values.

The engine accepts ',' and '.' interchangeably as the component separator, so
`Size="45.45"` is a 45x45 sprite, not a float. Every component is scaled
independently and the original separators, spacing and component count are
preserved byte-for-byte.

A value whose shape is not recognised is returned untouched. Passing through
an unknown shape is always preferable to guessing at it.
"""
import math
import re

_SEPARATORS = re.compile(r"([,.])")

# "505", "-40", "parent", "parent-40", "parent+15"
_INTEGER = re.compile(r"^(?P<ws1>\s*)(?P<num>-?\d+)(?P<ws2>\s*)$")
_KEYWORD = re.compile(
    r"^(?P<ws1>\s*)(?P<word>[A-Za-z_]\w*)(?:(?P<sign>[-+])(?P<num>\d+))?(?P<ws2>\s*)$"
)


def _round_half_away_from_zero(value: float) -> int:
    return int(math.floor(value + 0.5)) if value >= 0 else int(math.ceil(value - 0.5))


def _scale_int(text: str, scale: float) -> str:
    return str(_round_half_away_from_zero(int(text) * scale))


def _scale_component(component: str, scale: float):
    """Return the scaled component, or None if the shape is not recognised."""
    m = _INTEGER.match(component)
    if m:
        return m.group("ws1") + _scale_int(m.group("num"), scale) + m.group("ws2")

    m = _KEYWORD.match(component)
    if m:
        if m.group("num") is None:
            return component
        return (
            m.group("ws1")
            + m.group("word")
            + m.group("sign")
            + _scale_int(m.group("num"), scale)
            + m.group("ws2")
        )

    return None


def scale_value(value: str, scale: float) -> str:
    """Scale every numeric component of an attribute value."""
    return scale_value_checked(value, scale)[0]


def scale_value_checked(value: str, scale: float):
    """Scale a value, also reporting whether anything actually changed."""
    if not value:
        return value, False

    parts = _SEPARATORS.split(value)
    out = []
    for index, part in enumerate(parts):
        if index % 2:  # separators land on odd indices
            out.append(part)
            continue
        scaled = _scale_component(part, scale)
        if scaled is None:
            return value, False
        out.append(scaled)

    result = "".join(out)
    return result, result != value
