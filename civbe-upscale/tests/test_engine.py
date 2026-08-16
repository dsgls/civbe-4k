"""Engine tests, driven by a fake nearest-neighbour upscaler.

No GPU, no network, no checkpoints. These cover the two failures that would
masquerade as "the upscaler is mediocre" in game: padding that leaks into the
cropped result, and tiling that does not reassemble.
"""

from pathlib import Path

import numpy as np
import pytest
from PIL import Image

from civbe_upscale import engine
from civbe_upscale.registry import Checkpoint


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
    # Padded to 576x528, so a 512 px tile leaves a genuine 64x16 remainder tile
    # and the halo clips against every array bound.
    src = random_plane(500, 460, seed=1)

    untiled = engine.run_padded(nearest_2x, src, 2)
    tiled = engine.run_padded(nearest_2x, src, 2, tile=512)

    assert tiled.shape == untiled.shape
    np.testing.assert_array_equal(tiled, untiled)


def test_tile_not_larger_than_twice_the_overlap_is_refused():
    degenerate = 2 * engine.TILE_OVERLAP
    with pytest.raises(ValueError, match="2x overlap"):
        engine.tiled_run(nearest_2x, random_plane(800, 800), 2, tile=degenerate)


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


class VramLimitedFake:
    """nearest_2x that OOMs like CUDA does on any plane above ``limit`` px."""

    def __init__(self, limit: int):
        self.limit = limit
        self.oom_shapes = []

    def __call__(self, arr: np.ndarray) -> np.ndarray:
        if max(arr.shape[:2]) > self.limit:
            self.oom_shapes.append(arr.shape[:2])
            raise RuntimeError("CUDA out of memory. Tried to allocate 2.00 GiB")
        return nearest_2x(arr)


def looks_like_oom(exc: BaseException) -> bool:
    return isinstance(exc, RuntimeError) and "out of memory" in str(exc).lower()


def test_oom_halves_the_tile_size_until_inference_fits():
    # Padded to 272x272: whole-image, 128 px and 64 px tiles all exceed the
    # 50 px limit, so it takes two halvings to reach a tile that runs.
    src = random_plane(200, 200, seed=5)
    run = VramLimitedFake(limit=50)
    freed = []

    out = engine._run_with_oom_fallback(
        run,
        src,
        2,
        Image.LANCZOS,
        looks_like_oom,
        free_memory=lambda: freed.append(1),
        max_tile=128,
        overlap=8,
    )

    # One OOM per abandoned round: the whole image, then 128 and 64 px tiles.
    assert [max(shape) for shape in run.oom_shapes] == [272, 132, 68]
    assert len(freed) == 3
    np.testing.assert_array_equal(out, nearest_2x(src))


def test_oom_at_the_smallest_usable_tile_is_reported():
    run = VramLimitedFake(limit=0)

    with pytest.raises(RuntimeError, match="down to 32 px"):
        engine._run_with_oom_fallback(
            run, random_plane(200, 200, seed=6), 2, Image.LANCZOS, looks_like_oom,
            max_tile=128, overlap=8,
        )

    # 128, 64 and 32 px tiles tried; 16 would not exceed 2x the 8 px overlap.
    assert len(run.oom_shapes) == 4


def test_a_non_oom_failure_is_not_retried():
    def explode(arr):
        raise ValueError("bad weights")

    with pytest.raises(ValueError, match="bad weights"):
        engine._run_with_oom_fallback(
            explode, random_plane(16, 16), 2, Image.LANCZOS, looks_like_oom
        )


def test_build_upscaler_retries_only_when_given_an_oom_predicate():
    src = random_plane(100, 100, seed=7)
    # Padded to 168x168, which fits in one MAX_TILE tile, so the retry succeeds.
    calls = []

    def oom_first_call(arr):
        calls.append(arr.shape[:2])
        if len(calls) == 1:
            raise RuntimeError("CUDA out of memory")
        return nearest_2x(arr)

    retrying = engine.build_upscaler(oom_first_call, 2, is_oom=looks_like_oom)
    np.testing.assert_array_equal(retrying(src), nearest_2x(src))
    assert len(calls) == 2

    calls.clear()
    plain = engine.build_upscaler(oom_first_call, 2)
    with pytest.raises(RuntimeError, match="out of memory"):
        plain(src)


def test_a_checkpoint_is_loaded_once_for_both_plane_kinds(monkeypatch):
    loads = []

    class FakeModel:
        def __init__(self, path, scale):
            loads.append((path, scale))

    monkeypatch.setattr(engine, "SpandrelModel", FakeModel)
    monkeypatch.setattr(engine, "_MODEL_CACHE", {})

    rgb = engine.load_model(Path("dat2.pth"), 4)
    alpha = engine.load_model(Path("dat2.pth"), 4)
    other = engine.load_model(Path("swinir.pth"), 4)

    assert rgb is alpha
    assert other is not rgb
    assert loads == [(Path("dat2.pth"), 4), (Path("swinir.pth"), 4)]


def test_ensure_checkpoint_hashes_a_cached_file_only_once(tmp_path, monkeypatch):
    """A second `ensure_checkpoint` call for the same path must not re-hash.

    `apply_upscalers` resolves each upscaler name once per plane kind per
    image, so an unmemoized hash turns a batch run into two full-file SHA-256
    passes per image per upscaler.
    """
    monkeypatch.setattr(engine, "_VERIFIED_CHECKPOINTS", set())
    monkeypatch.setattr(engine, "models_dir", lambda: tmp_path)

    target = tmp_path / "model.pth"
    target.write_bytes(b"pretend model weights")
    ckpt = Checkpoint(url=f"https://example.invalid/{target.name}", sha256=engine._sha256(target))

    calls = []
    real_sha256 = engine._sha256

    def counting_sha256(path):
        calls.append(path)
        return real_sha256(path)

    monkeypatch.setattr(engine, "_sha256", counting_sha256)

    first = engine.ensure_checkpoint(ckpt)
    second = engine.ensure_checkpoint(ckpt)

    assert first == target
    assert second == target
    assert calls == [target]


def test_non_float32_plane_is_rejected():
    with pytest.raises(ValueError, match="float32"):
        engine.run_padded(nearest_2x, np.zeros((4, 4, 3), dtype=np.uint8), 2)
