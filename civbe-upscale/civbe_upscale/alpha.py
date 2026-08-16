"""Two-plane alpha pipeline.

Every upscaler except `lanczos-rgba` runs through `upscale_rgba`, which splits
an RGBA image into an RGB plane and an alpha plane, upscales each separately,
and recombines. The split exists so the upscaler never sees the discontinuity
between real art and the junk colors authored under transparent pixels: those
colors are replaced by extrapolation from the visible art first.

Plane data is float32 in [0,1] everywhere; every value is clamped before it is
quantized back to uint8.
"""

from __future__ import annotations

from typing import Callable

import numpy as np
from PIL import Image

# A 2x upscaler over one RGB-shaped float plane. Contract: input float32
# HxWx3 in [0,1], output float32 2Hx2Wx3 in [0,1], already clamped.
PlaneUpscaler = Callable[[np.ndarray], np.ndarray]

# Alpha (in 8-bit units) below which the authored RGB is treated as junk and
# blended toward the extrapolated color by `1 - a/threshold`.
BLEND_THRESHOLD = 8.0

_NEIGHBORS = ((-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1))


def upscale_rgba(img: Image.Image, up: PlaneUpscaler) -> Image.Image:
    """Upscale an RGBA image 2x through the two-plane path."""
    rgb, alpha = _to_planes(img)

    rgb = extrapolate_color(rgb, alpha)
    rgb2 = _upscale_plane(rgb, up)

    alpha3 = np.repeat(alpha[:, :, None], 3, axis=2)
    alpha2 = _upscale_plane(alpha3, up).mean(axis=2)

    out = np.concatenate([rgb2, np.clip(alpha2, 0.0, 1.0)[:, :, None]], axis=2)
    return _to_image(out)


def upscale_rgba_direct(img: Image.Image) -> Image.Image:
    """Diagnostic control: one-pass RGBA LANCZOS, no split, no extrapolation.

    If this ever beats the two-plane `lanczos` on soft edges, the pipeline
    above has a bug. Pillow clamps its uint8 resample internally, so the
    [0,1] rule holds without a float round-trip.
    """
    _check_rgba(img)
    w, h = img.size
    return img.resize((w * 2, h * 2), Image.LANCZOS)


def extrapolate_color(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Replace junk RGB under (near-)transparent pixels with neighbor color.

    Seeds are the pixels whose color is trustworthy, weighted by their alpha
    so a faint glow still seeds without dragging the average toward its own
    dim color. Everything below `BLEND_THRESHOLD` is refilled by iterative
    8-connected dilation of the seed set: each round, an unfilled pixel takes
    the alpha-weighted mean of its already-filled neighbors, so a pixel with a
    unique nearest seed ends up with exactly that seed's color.

    The result is blended in by `1 - a/threshold`, i.e. fully replacing color
    at alpha 0 and fading to a no-op at the threshold. Above the threshold the
    authored color is left alone.

    Two degenerate cases matter on the real work list:
    * no pixel at or above the threshold (a whole sprite drawn in faint glow):
      fall back to seeding from every pixel with alpha > 0, which still lets
      the fully transparent margin be filled.
    * no pixel with alpha > 0 at all: there is nothing to extrapolate from, so
      the plane passes through unchanged.
    """
    a8 = alpha * 255.0
    seeds = a8 >= BLEND_THRESHOLD - 1e-4
    if not seeds.any():
        seeds = a8 > 0.0
        if not seeds.any():
            return rgb

    filled = _dilate(rgb, alpha, seeds)

    blend = np.clip(1.0 - a8 / BLEND_THRESHOLD, 0.0, 1.0)[:, :, None]
    return np.clip(filled * blend + rgb * (1.0 - blend), 0.0, 1.0).astype(np.float32)


def _dilate(rgb: np.ndarray, alpha: np.ndarray, seeds: np.ndarray) -> np.ndarray:
    color = np.where(seeds[:, :, None], rgb, 0.0).astype(np.float32)
    weight = np.where(seeds, alpha, 0.0).astype(np.float32)
    known = seeds.copy()

    while not known.all():
        num = np.zeros_like(color)
        den = np.zeros_like(weight)
        count = np.zeros_like(weight)
        contrib = color * weight[:, :, None]
        for dy, dx in _NEIGHBORS:
            num += _shift(contrib, dy, dx)
            den += _shift(weight, dy, dx)
            count += _shift(known.astype(np.float32), dy, dx)

        frontier = ~known & (den > 0.0)
        if not frontier.any():
            # Disconnected only if the image has no seed at all, which the
            # caller already excluded; guard against an infinite loop anyway.
            break
        color[frontier] = num[frontier] / den[frontier][:, None]
        weight[frontier] = den[frontier] / count[frontier]
        known |= frontier

    return color


def _shift(a: np.ndarray, dy: int, dx: int) -> np.ndarray:
    """`a` translated by (dy, dx), with zeros shifted in at the border."""
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    src_y = slice(max(0, -dy), h - max(0, dy))
    dst_y = slice(max(0, dy), h - max(0, -dy))
    src_x = slice(max(0, -dx), w - max(0, dx))
    dst_x = slice(max(0, dx), w - max(0, -dx))
    out[dst_y, dst_x] = a[src_y, src_x]
    return out


def _upscale_plane(plane: np.ndarray, up: PlaneUpscaler) -> np.ndarray:
    """Run one plane through the upscaler, or fill it if it is constant.

    A globally constant plane (opaque alpha, blank placeholder RGB) has
    nothing to upscale, and GAN-family models speckle flat regions.
    """
    h, w, _ = plane.shape
    first = plane.reshape(-1, 3)[0]
    if np.array_equal(plane, np.broadcast_to(first, plane.shape)):
        return np.broadcast_to(first, (h * 2, w * 2, 3)).astype(np.float32)

    out = up(plane)
    if out.shape != (h * 2, w * 2, 3):
        raise ValueError(f"upscaler returned {out.shape}, expected {(h * 2, w * 2, 3)}")
    return np.clip(out, 0.0, 1.0).astype(np.float32)


def _check_rgba(img: Image.Image) -> None:
    if img.mode != "RGBA":
        raise ValueError(f"expected an RGBA image, got mode {img.mode!r}")


def _to_planes(img: Image.Image) -> tuple[np.ndarray, np.ndarray]:
    _check_rgba(img)
    arr = np.asarray(img, dtype=np.float32) / 255.0
    return arr[:, :, :3].copy(), arr[:, :, 3].copy()


def _to_image(arr: np.ndarray) -> Image.Image:
    quantized = np.rint(np.clip(arr, 0.0, 1.0) * 255.0).astype(np.uint8)
    return Image.fromarray(quantized, mode="RGBA")
