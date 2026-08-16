"""Engine tests, driven by a fake nearest-neighbour upscaler.

No GPU, no network, no checkpoints. These cover the two failures that would
masquerade as "the upscaler is mediocre" in game: padding that leaks into the
cropped result, and tiling that does not reassemble.
"""

import numpy as np
import pytest
from PIL import Image

from civbe_upscale import engine


def nearest_2x(arr: np.ndarray) -> np.ndarray:
    """Exact 2x nearest neighbour: shift-equivariant with a 1-pixel footprint."""
    return np.repeat(np.repeat(arr, 2, axis=0), 2, axis=1)


def random_plane(h: int, w: int, seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.random((h, w, 3), dtype=np.float32)


@pytest.mark.parametrize("shape", [(8, 5), (4, 32), (1, 1), (17, 33)])
def test_pad_run_crop_round_trip(shape):
    src = random_plane(*shape)
    out = engine.run_padded(nearest_2x, src, 2)

    assert out.shape == (shape[0] * 2, shape[1] * 2, 3)
    np.testing.assert_array_equal(out, nearest_2x(src))


def test_padding_reaches_the_minimum_and_a_multiple_of_sixteen():
    padded, pad_x, pad_y = engine.pad_replicate(random_plane(8, 5))

    assert (pad_x, pad_y) == (engine.MIN_PAD, engine.MIN_PAD)
    assert padded.shape[0] >= 8 + 2 * engine.MIN_PAD
    assert padded.shape[1] >= 5 + 2 * engine.MIN_PAD
    assert padded.shape[0] % engine.PAD_MULTIPLE == 0
    assert padded.shape[1] % engine.PAD_MULTIPLE == 0


def test_tiled_output_is_identical_to_untiled():
    src = random_plane(500, 460, seed=1)

    untiled = engine.run_padded(nearest_2x, src, 2)
    tiled = engine.run_padded(nearest_2x, src, 2, tile=256)

    assert tiled.shape == untiled.shape
    np.testing.assert_array_equal(tiled, untiled)


def test_tile_not_larger_than_twice_the_overlap_is_refused():
    with pytest.raises(ValueError, match="2x overlap"):
        engine.tiled_run(nearest_2x, random_plane(200, 200), 2, tile=128, overlap=64)


def test_four_x_runner_is_normalized_to_two_x():
    def nearest_4x(arr):
        return np.repeat(np.repeat(arr, 4, axis=0), 4, axis=1)

    upscale = engine.build_upscaler(nearest_4x, 4)
    out = upscale(random_plane(9, 7, seed=2))

    assert out.shape == (18, 14, 3)
    assert out.dtype == np.float32


def test_four_x_normalization_downscales_before_cropping():
    """The 4x->2x downscale must see the padding, not the crop edge.

    Downscaling an already-cropped plane resamples its border against Pillow's
    clamped edge, which puts a subtly wrong outermost row on every output. The
    expected value here is built the other way round — downscale the whole
    padded 4x plane, then crop — and only matches if the engine does the same.
    """
    def nearest_4x(arr):
        return np.repeat(np.repeat(arr, 4, axis=0), 4, axis=1)

    src = random_plane(24, 24, seed=4)
    out = engine.build_upscaler(nearest_4x, 4)(src)

    padded, pad_x, pad_y = engine.pad_replicate(src)
    ph, pw = padded.shape[:2]
    big = engine.resize_planes(nearest_4x(padded), (pw * 2, ph * 2), Image.LANCZOS)
    expected = big[pad_y * 2 : pad_y * 2 + 48, pad_x * 2 : pad_x * 2 + 48]

    np.testing.assert_array_equal(out, expected)


def test_alpha_plane_normalization_uses_a_non_negative_kernel():
    """Lanczos' negative lobes ring alpha above zero outside a hard edge."""
    def nearest_4x(arr):
        return np.repeat(np.repeat(arr, 4, axis=0), 4, axis=1)

    # A hard-edged binary mask: left half opaque, right half fully transparent.
    src = np.zeros((16, 16, 3), dtype=np.float32)
    src[:, :8] = 1.0

    alpha = engine.build_upscaler(nearest_4x, 4, alpha_plane=True)(src)
    rgb = engine.build_upscaler(nearest_4x, 4)(src)

    # BOX never overshoots, so the transparent side stays exactly zero.
    assert alpha[:, 16:].max() == 0.0
    assert rgb[:, 16:].max() > 0.0


def test_output_is_clamped_to_unit_range():
    def overshooting(arr):
        return nearest_2x(arr) * 4.0 - 1.5

    upscale = engine.build_upscaler(overshooting, 2)
    out = upscale(random_plane(8, 8, seed=3))

    assert out.min() >= 0.0
    assert out.max() <= 1.0


def test_non_float32_plane_is_rejected():
    with pytest.raises(ValueError, match="float32"):
        engine.run_padded(nearest_2x, np.zeros((4, 4, 3), dtype=np.uint8), 2)
