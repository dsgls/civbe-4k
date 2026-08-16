"""Alpha-pipeline tests, driven by a fake nearest-neighbor upscaler.

The module is loaded from its file rather than imported as part of the
package so these tests run without the rest of `civbe_upscale`.
"""

import importlib.util
import pathlib
import sys

import numpy as np
import pytest
from PIL import Image

_PATH = pathlib.Path(__file__).resolve().parents[1] / "civbe_upscale" / "alpha.py"
_spec = importlib.util.spec_from_file_location("civbe_upscale_alpha", _PATH)
alpha = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = alpha
_spec.loader.exec_module(alpha)


class FakeUpscaler:
    """Nearest-neighbor 2x that records every plane it is handed."""

    def __init__(self):
        self.calls = []

    def __call__(self, plane):
        assert plane.dtype == np.float32
        assert plane.ndim == 3 and plane.shape[2] == 3
        assert plane.min() >= 0.0 and plane.max() <= 1.0
        self.calls.append(plane.copy())
        return np.repeat(np.repeat(plane, 2, axis=0), 2, axis=1)


def make_image(rgba):
    return Image.fromarray(np.asarray(rgba, dtype=np.uint8), mode="RGBA")


def nearest2x(arr):
    return np.repeat(np.repeat(np.asarray(arr, dtype=np.uint8), 2, axis=0), 2, axis=1)


def solid(h, w, rgba):
    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[:, :] = rgba
    return out


# --- split / recombine ---------------------------------------------------


def test_round_trip_matches_nearest_upscale():
    rng = np.random.default_rng(0)
    src = np.empty((4, 5, 4), dtype=np.uint8)
    src[:, :, :3] = rng.integers(0, 256, (4, 5, 3), dtype=np.uint8)
    # Vary alpha so neither plane takes the constant-passthrough path, but
    # keep it above the blend threshold so no RGB is rewritten.
    src[:, :, 3] = rng.integers(64, 256, (4, 5), dtype=np.uint8)

    out = alpha.upscale_rgba(make_image(src), FakeUpscaler())

    assert out.mode == "RGBA"
    assert out.size == (10, 8)
    np.testing.assert_array_equal(np.asarray(out), nearest2x(src))


def test_partial_alpha_rgb_untouched_above_threshold():
    src = solid(3, 3, (10, 200, 30, 128))
    src[1, 1] = (90, 40, 250, 8)
    fake = FakeUpscaler()

    alpha.upscale_rgba(make_image(src), fake)

    seen = np.rint(fake.calls[0] * 255.0).astype(np.uint8)
    np.testing.assert_array_equal(seen, src[:, :, :3])


def test_transparent_rgb_extrapolated_before_the_upscaler_sees_it():
    src = solid(1, 4, (7, 7, 7, 0))  # junk under the transparent pixels
    src[0, 0] = (200, 100, 50, 255)
    src[0, 3] = (0, 60, 90, 255)
    fake = FakeUpscaler()

    alpha.upscale_rgba(make_image(src), fake)

    seen = np.rint(fake.calls[0] * 255.0).astype(np.uint8)
    np.testing.assert_array_equal(seen[0, 1], (200, 100, 50))
    np.testing.assert_array_equal(seen[0, 2], (0, 60, 90))


def test_near_transparent_rgb_blended_toward_extrapolation():
    src = solid(1, 3, (0, 0, 0, 0))
    src[0, 0] = (200, 0, 0, 255)
    src[0, 1] = (0, 0, 100, 4)  # alpha 4 of 8 -> half its own color
    src[0, 2] = (0, 255, 0, 255)  # keeps the plane from going constant
    fake = FakeUpscaler()

    alpha.upscale_rgba(make_image(src), fake)

    # Extrapolated color at [0,1] is the alpha-weighted mean of both seeds.
    seen = fake.calls[0][0, 1] * 255.0
    np.testing.assert_allclose(seen, (50.0, 63.75, 50.0), atol=0.5)


def test_alpha_plane_is_replicated_and_averaged_back():
    # Unsaturated alpha, so the imbalance is not clipped asymmetrically.
    src = solid(1, 2, (10, 20, 30, 200))
    src[0, 1] = (40, 50, 60, 40)

    class Imbalanced(FakeUpscaler):
        def __call__(self, plane):
            out = super().__call__(plane)
            return np.clip(out + np.array([0.02, 0.0, -0.02], np.float32), 0.0, 1.0)

    fake = Imbalanced()
    out = np.asarray(alpha.upscale_rgba(make_image(src), fake))

    # Two calls: the alpha plane arrives as 3-channel grayscale.
    assert len(fake.calls) == 2
    grey = fake.calls[1]
    np.testing.assert_allclose(grey[:, :, 0], grey[:, :, 1])
    np.testing.assert_allclose(grey[:, :, 0], grey[:, :, 2])
    # The channel imbalance averages back out.
    np.testing.assert_array_equal(out[:, :, 3], nearest2x(src)[:, :, 3])


# --- degenerate images ---------------------------------------------------


def test_fully_opaque_image_survives():
    src = np.zeros((2, 2, 4), dtype=np.uint8)
    src[:, :, :3] = [[[1, 2, 3], [4, 5, 6]], [[7, 8, 9], [10, 11, 12]]]
    src[:, :, 3] = 255
    fake = FakeUpscaler()

    out = np.asarray(alpha.upscale_rgba(make_image(src), fake))

    np.testing.assert_array_equal(out, nearest2x(src))
    assert len(fake.calls) == 1  # constant alpha plane never reaches the upscaler


def test_zero_seed_image_passes_rgb_through():
    src = np.zeros((2, 3, 4), dtype=np.uint8)
    src[:, :, :3] = 77
    src[0, 0, :3] = (1, 2, 3)  # junk, but nothing is visible anywhere
    fake = FakeUpscaler()

    out = np.asarray(alpha.upscale_rgba(make_image(src), fake))

    seen = np.rint(fake.calls[0] * 255.0).astype(np.uint8)
    np.testing.assert_array_equal(seen, src[:, :, :3])
    np.testing.assert_array_equal(out, nearest2x(src))


def test_faint_glow_seeds_below_the_threshold():
    """No pixel reaches alpha 8, so the seed set falls back to alpha > 0."""
    src = solid(1, 4, (0, 0, 0, 0))
    src[0, 0] = (240, 120, 60, 5)
    src[0, 3] = (0, 0, 240, 5)
    fake = FakeUpscaler()

    alpha.upscale_rgba(make_image(src), fake)

    seen = np.rint(fake.calls[0] * 255.0).astype(np.uint8)
    np.testing.assert_array_equal(seen[0, 1], (240, 120, 60))
    np.testing.assert_array_equal(seen[0, 2], (0, 0, 240))


def test_constant_planes_pass_through_without_the_upscaler():
    src = solid(3, 4, (60, 60, 60, 255))
    fake = FakeUpscaler()

    out = np.asarray(alpha.upscale_rgba(make_image(src), fake))

    assert fake.calls == []
    np.testing.assert_array_equal(out, nearest2x(src))


def test_blank_rgb_with_varying_alpha_only_upscales_alpha():
    src = solid(2, 2, (0, 0, 0, 255))
    src[0, 0, 3] = 128
    fake = FakeUpscaler()

    out = np.asarray(alpha.upscale_rgba(make_image(src), fake))

    assert len(fake.calls) == 1
    np.testing.assert_array_equal(out, nearest2x(src))


def test_non_rgba_input_is_an_error():
    with pytest.raises(ValueError):
        alpha.upscale_rgba(Image.new("RGB", (2, 2)), FakeUpscaler())
    with pytest.raises(ValueError):
        alpha.upscale_rgba_direct(Image.new("RGB", (2, 2)))


def test_out_of_range_upscaler_output_is_clamped():
    src = solid(2, 2, (10, 250, 10, 200))
    src[0, 0, 3] = 30

    def overshoot(plane):
        out = np.repeat(np.repeat(plane, 2, axis=0), 2, axis=1)
        return out * 4.0 - 1.0

    out = np.asarray(alpha.upscale_rgba(make_image(src), overshoot))

    assert out.dtype == np.uint8
    assert out.min() >= 0 and out.max() <= 255


# --- color extrapolation -------------------------------------------------


def extrapolate(rgb_u8, alpha_u8):
    rgb = np.asarray(rgb_u8, dtype=np.float32) / 255.0
    a = np.asarray(alpha_u8, dtype=np.float32) / 255.0
    out = alpha.extrapolate_color(rgb, a)
    return np.rint(out * 255.0).astype(np.uint8)


def test_extrapolation_fills_from_the_nearest_seed():
    rgb = np.zeros((1, 5, 3), dtype=np.uint8)
    rgb[0, 0] = (255, 0, 0)
    rgb[0, 4] = (0, 0, 255)
    a = np.array([[255, 0, 0, 0, 255]], dtype=np.uint8)

    out = extrapolate(rgb, a)

    np.testing.assert_array_equal(out[0, 1], (255, 0, 0))
    np.testing.assert_array_equal(out[0, 3], (0, 0, 255))
    # The middle pixel is equidistant, so it averages the two seeds.
    np.testing.assert_array_equal(out[0, 2], (128, 0, 128))


def test_extrapolation_is_eight_connected_diagonally():
    rgb = np.zeros((3, 3, 3), dtype=np.uint8)
    rgb[0, 0] = (10, 20, 30)
    a = np.zeros((3, 3), dtype=np.uint8)
    a[0, 0] = 255

    out = extrapolate(rgb, a)

    assert (out == (10, 20, 30)).all()


def test_extrapolation_weights_seeds_by_alpha():
    rgb = np.zeros((1, 3, 3), dtype=np.uint8)
    rgb[0, 0] = (255, 0, 0)
    rgb[0, 2] = (0, 255, 0)
    a = np.array([[255, 0, 51]], dtype=np.uint8)  # 5:1 weight toward red

    out = extrapolate(rgb, a)

    r, g, b = out[0, 1]
    assert b == 0
    assert r > g > 0
    np.testing.assert_allclose([r, g], [255 * 5 / 6, 255 * 1 / 6], atol=1.0)


def test_extrapolation_leaves_opaque_pixels_alone():
    rng = np.random.default_rng(1)
    rgb = rng.integers(0, 256, (4, 4, 3), dtype=np.uint8)
    a = np.full((4, 4), 255, dtype=np.uint8)
    a[0, 0] = 0

    out = extrapolate(rgb, a)

    np.testing.assert_array_equal(out[1:], rgb[1:])
    np.testing.assert_array_equal(out[0, 1:], rgb[0, 1:])


def test_alpha_up_used_for_alpha_plane_when_given():
    src = solid(2, 2, (10, 20, 30, 200))
    src[0, 0] = (40, 50, 60, 128)  # keep both planes non-constant
    rgb_up = FakeUpscaler()
    alpha_up = FakeUpscaler()

    alpha.upscale_rgba(make_image(src), rgb_up, alpha_up=alpha_up)

    assert len(rgb_up.calls) == 1  # only the RGB plane
    assert len(alpha_up.calls) == 1  # only the alpha plane
    np.testing.assert_array_equal(rgb_up.calls[0][:, :, 0] * 255.0, src[:, :, 0])


# --- lanczos-rgba bypass -------------------------------------------------


def test_direct_bypass_is_a_single_rgba_resize():
    rng = np.random.default_rng(2)
    src = rng.integers(0, 256, (5, 7, 4), dtype=np.uint8)
    img = make_image(src)

    out = alpha.upscale_rgba_direct(img)

    assert out.mode == "RGBA"
    assert out.size == (14, 10)
    np.testing.assert_array_equal(
        np.asarray(out), np.asarray(img.resize((14, 10), Image.LANCZOS))
    )
