"""Tests for `apply_upscalers`' once-per-input extrapolation.

`apply_upscaler` (singular) is exercised end to end by the CLI smoke tests
recorded in the task output, not here -- it needs a real or fake model, and
the only thing worth pinning at this layer is the shared-plane property.
"""

from __future__ import annotations

import numpy as np
from PIL import Image

from civbe_upscale import alpha, apply


def make_image() -> Image.Image:
    rng = np.random.default_rng(4)
    arr = np.empty((4, 4, 4), dtype=np.uint8)
    arr[:, :, :3] = rng.integers(0, 256, (4, 4, 3), dtype=np.uint8)
    arr[:, :, 3] = rng.integers(0, 256, (4, 4), dtype=np.uint8)
    return Image.fromarray(arr, mode="RGBA")


def test_apply_upscalers_extrapolates_once_per_input(monkeypatch):
    real_prepare = alpha.prepare_rgb_plane
    calls = []

    def counting_prepare(img):
        calls.append(img)
        return real_prepare(img)

    monkeypatch.setattr(alpha, "prepare_rgb_plane", counting_prepare)

    img = make_image()
    # Two non-bypass entries (share the plane) plus a bypass entry (never
    # touches it), all built-in so the test needs no checkpoint or GPU.
    results = list(apply.apply_upscalers(["lanczos", "lanczos-rgba", "lanczos"], img))

    assert len(calls) == 1
    assert [name for name, _ in results] == ["lanczos", "lanczos-rgba", "lanczos"]
    for _, out in results:
        assert out.mode == "RGBA"
        assert out.size == (8, 8)
