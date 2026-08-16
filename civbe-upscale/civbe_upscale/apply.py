"""Single routing point from a registry name to a 2x-upscaled RGBA image.

Both `batch` and `compare` call `apply_upscaler` (or `apply_upscalers`, for
several names at once) so the `bypass_alpha` rule (currently only
`lanczos-rgba`) lives in exactly one place.
"""

from __future__ import annotations

from collections.abc import Iterator

from PIL import Image

from . import alpha
from .engine import get_upscaler
from .registry import REGISTRY, Entry


def _lookup(name: str) -> Entry:
    try:
        return REGISTRY[name]
    except KeyError:
        raise KeyError(
            f"unknown upscaler {name!r}; known: {', '.join(sorted(REGISTRY))}"
        ) from None


def apply_upscaler(name: str, img: Image.Image) -> Image.Image:
    """Upscale ``img`` 2x through the upscaler registered as ``name``."""
    entry = _lookup(name)
    if entry.bypass_alpha:
        return alpha.upscale_rgba_direct(img)

    up = get_upscaler(name)
    alpha_up = get_upscaler(name, alpha_plane=True)
    return alpha.upscale_rgba(img, up, alpha_up=alpha_up)


def apply_upscalers(names: list[str], img: Image.Image) -> Iterator[tuple[str, Image.Image]]:
    """Upscale ``img`` 2x through every upscaler in ``names``, in order.

    Non-bypass upscalers share one extrapolated RGB plane, prepared from
    ``img`` the first time it is needed: the dilation step (see
    ``alpha.MAX_DILATION_ROUNDS``) doesn't depend on which upscaler runs
    next, so comparing several upscalers over one input pays for it once
    instead of once per upscaler. ``bypass_alpha`` entries (`lanczos-rgba`)
    route to ``alpha.upscale_rgba_direct`` as before and never touch the
    shared plane.
    """
    prepared_rgb = None
    for name in names:
        entry = _lookup(name)
        if entry.bypass_alpha:
            yield name, alpha.upscale_rgba_direct(img)
            continue

        if prepared_rgb is None:
            prepared_rgb = alpha.prepare_rgb_plane(img)
        up = get_upscaler(name)
        alpha_up = get_upscaler(name, alpha_plane=True)
        yield name, alpha.upscale_rgba(img, up, alpha_up=alpha_up, prepared_rgb=prepared_rgb)
