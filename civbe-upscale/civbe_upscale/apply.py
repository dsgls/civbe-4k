"""Single routing point from a registry name to a 2x-upscaled RGBA image.

Both `batch` and `compare` call `apply_upscaler` so the `bypass_alpha` rule
(currently only `lanczos-rgba`) lives in exactly one place.
"""

from __future__ import annotations

from PIL import Image

from . import alpha
from .engine import get_upscaler
from .registry import REGISTRY


def apply_upscaler(name: str, img: Image.Image) -> Image.Image:
    """Upscale ``img`` 2x through the upscaler registered as ``name``."""
    try:
        entry = REGISTRY[name]
    except KeyError:
        raise KeyError(
            f"unknown upscaler {name!r}; known: {', '.join(sorted(REGISTRY))}"
        ) from None

    if entry.bypass_alpha:
        return alpha.upscale_rgba_direct(img)

    up = get_upscaler(name)
    alpha_up = get_upscaler(name, alpha_plane=True)
    return alpha.upscale_rgba(img, up, alpha_up=alpha_up)
