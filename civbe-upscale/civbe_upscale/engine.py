"""The upscaling engine: checkpoint cache, spandrel wrapper, padding, tiling.

The engine's whole contract with the rest of the tool is `PlaneUpscaler`: a
callable taking one float32 HxWx3 plane in [0,1] and returning a float32
2Hx2Wx3 plane in [0,1]. Padding, tiling, device placement and scale
normalization all happen behind it.

Plane data is float in [0,1] everywhere and is clamped after every model
invocation and every resize. Casting an unclamped float plane to uint8 wraps
alpha overshoot at hard edges into punched-out transparent rings.
"""

from __future__ import annotations

import hashlib
import logging
import os
import urllib.request
from collections.abc import Callable
from pathlib import Path

import numpy as np
from PIL import Image

from .registry import REGISTRY, Checkpoint, Entry

log = logging.getLogger(__name__)

#: The engine's public contract: HxWx3 float32 in [0,1] -> 2Hx2Wx3 float32 in [0,1].
PlaneUpscaler = Callable[[np.ndarray], np.ndarray]
#: Same shape of callable, but at a model's *native* scale and without padding.
PlaneRunner = Callable[[np.ndarray], np.ndarray]

#: A plane is replicate-padded by at least this much per side before inference.
MIN_PAD = 32
#: ...and the padded size is rounded up to a multiple of this.
PAD_MULTIPLE = 16
#: First tile size tried when whole-image inference hits CUDA OOM.
MAX_TILE = 1024
#: Input-space overlap between neighbouring tiles; constant while tiles halve.
#: Half of it is the context halo each interior tile side reads and discards, so
#: 128 buys 64 px of real context — tiling is the routine path for the 2048 px
#: atlas tier, and the shifted-window transformers in the registry have
#: effective receptive fields well past 32 px.
TILE_OVERLAP = 128

_DOWNLOAD_CHUNK = 1 << 20


# --------------------------------------------------------------------------
# array helpers
# --------------------------------------------------------------------------


def _check_plane(arr: np.ndarray) -> None:
    if arr.dtype != np.float32:
        raise ValueError(f"plane must be float32, got {arr.dtype}")
    if arr.ndim != 3 or arr.shape[2] != 3:
        raise ValueError(f"plane must be HxWx3, got shape {arr.shape}")


def resize_planes(arr: np.ndarray, size: tuple[int, int], resample: int) -> np.ndarray:
    """Resize a float32 HxWxC plane to ``size`` = (width, height), clamped.

    Each channel goes through Pillow as a mode-"F" image, so the resize stays
    in float and never round-trips through uint8.
    """
    w, h = size
    out = np.empty((h, w, arr.shape[2]), dtype=np.float32)
    for c in range(arr.shape[2]):
        chan = np.ascontiguousarray(arr[:, :, c], dtype=np.float32)
        resized = Image.fromarray(chan, mode="F").resize((w, h), resample)
        out[:, :, c] = np.asarray(resized, dtype=np.float32)
    return np.clip(out, 0.0, 1.0, out=out)


def pad_replicate(arr: np.ndarray) -> tuple[np.ndarray, int, int]:
    """Replicate-pad to at least MIN_PAD per side, size a multiple of PAD_MULTIPLE.

    Returns the padded array and the left/top pad, which is what the caller
    needs to crop the result back out. Replicate rather than reflect: the work
    list bottoms out at 8x5, too small to reflect-pad past its own size, and
    replicate keeps 9-slice border rows clean.
    """
    h, w = arr.shape[:2]
    extra_x = -(w + 2 * MIN_PAD) % PAD_MULTIPLE
    extra_y = -(h + 2 * MIN_PAD) % PAD_MULTIPLE
    padded = np.pad(
        arr,
        ((MIN_PAD, MIN_PAD + extra_y), (MIN_PAD, MIN_PAD + extra_x), (0, 0)),
        mode="edge",
    )
    return padded, MIN_PAD, MIN_PAD


def tiled_run(
    run: PlaneRunner,
    arr: np.ndarray,
    scale: int,
    tile: int,
    overlap: int = TILE_OVERLAP,
) -> np.ndarray:
    """Run ``run`` over ``arr`` in tiles of ``tile`` px, assembling the output.

    Each tile reads ``overlap // 2`` px of extra context on every interior side
    and its output is cropped back to the tile's own rect — no blending, so for
    a shift-equivariant operator with a receptive field inside the halo the
    result is identical to a whole-image run. Model receptive fields are not
    guaranteed to fit, so tiled ML output is *close to* but not certainly the
    same as untiled.
    """
    if tile <= 2 * overlap:
        raise ValueError(f"tile size {tile} is not larger than 2x overlap {overlap}")
    h, w = arr.shape[:2]
    halo = overlap // 2
    out = np.empty((h * scale, w * scale, arr.shape[2]), dtype=np.float32)
    for y0 in range(0, h, tile):
        y1 = min(y0 + tile, h)
        for x0 in range(0, w, tile):
            x1 = min(x0 + tile, w)
            sy0, sy1 = max(0, y0 - halo), min(h, y1 + halo)
            sx0, sx1 = max(0, x0 - halo), min(w, x1 + halo)
            piece = run(arr[sy0:sy1, sx0:sx1])
            oy, ox = (y0 - sy0) * scale, (x0 - sx0) * scale
            out[y0 * scale : y1 * scale, x0 * scale : x1 * scale] = piece[
                oy : oy + (y1 - y0) * scale, ox : ox + (x1 - x0) * scale
            ]
    return out


def run_padded(
    run: PlaneRunner,
    arr: np.ndarray,
    scale: int,
    *,
    tile: int | None = None,
    overlap: int = TILE_OVERLAP,
    out_scale: int | None = None,
    resample: int = Image.LANCZOS,
) -> np.ndarray:
    """Pad, run at ``scale``, normalize to ``out_scale``, crop the original rect.

    ``out_scale`` defaults to ``scale`` (no normalization). The normalization
    happens on the still-padded plane, before the crop: downscaling a plane that
    has already been cropped resamples its outermost pixels against Pillow's
    clamped edge instead of against the replicate padding, putting a subtly
    wrong border row on every output — exactly what the padding exists to
    prevent, and it lands on the 9-slice border art that reads it.
    """
    _check_plane(arr)
    h, w = arr.shape[:2]
    padded, pad_x, pad_y = pad_replicate(arr)
    ph, pw = padded.shape[:2]
    if tile is None:
        result = run(padded)
    else:
        result = tiled_run(run, padded, scale, tile, overlap)
    expected = (ph * scale, pw * scale)
    if result.shape[:2] != expected:
        raise RuntimeError(
            f"upscaler returned {result.shape[:2]}, expected {expected} at {scale}x"
        )
    result = np.clip(result, 0.0, 1.0)

    if out_scale is None:
        out_scale = scale
    if out_scale != scale:
        result = resize_planes(result, (pw * out_scale, ph * out_scale), resample)

    x0, y0 = pad_x * out_scale, pad_y * out_scale
    # Copy rather than return the view: a view would keep the whole padded
    # buffer alive behind a much smaller result, and an atlas plane's padded
    # buffer runs to hundreds of MB.
    return np.ascontiguousarray(
        result[y0 : y0 + h * out_scale, x0 : x0 + w * out_scale]
    )


# --------------------------------------------------------------------------
# checkpoint cache
# --------------------------------------------------------------------------


def models_dir() -> Path:
    override = os.environ.get("CIVBE_UPSCALE_MODELS")
    if override:
        return Path(override)
    return Path(__file__).resolve().parent.parent / "models"


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        while chunk := fh.read(_DOWNLOAD_CHUNK):
            digest.update(chunk)
    return digest.hexdigest()


#: Checkpoint paths already hash-verified in this process; `ensure_checkpoint`
#: trusts these without re-hashing. `apply_upscalers` resolves each upscaler
#: name per image, so without this a batch run re-hashes every checkpoint
#: once per image.
_VERIFIED_CHECKPOINTS: set[Path] = set()


def ensure_checkpoint(ckpt: Checkpoint) -> Path:
    """Return the cached checkpoint path, downloading and verifying if needed."""
    target = models_dir() / ckpt.filename
    if target in _VERIFIED_CHECKPOINTS:
        return target

    if target.exists():
        actual = _sha256(target)
        if actual == ckpt.sha256:
            _VERIFIED_CHECKPOINTS.add(target)
            return target
        raise RuntimeError(
            f"cached {target} has sha256 {actual}, expected {ckpt.sha256}; "
            "delete it to re-download"
        )

    target.parent.mkdir(parents=True, exist_ok=True)
    partial = target.with_suffix(target.suffix + ".part")
    log.info("downloading %s", ckpt.url)
    with urllib.request.urlopen(ckpt.url) as response, partial.open("wb") as fh:
        while chunk := response.read(_DOWNLOAD_CHUNK):
            fh.write(chunk)
    actual = _sha256(partial)
    if actual != ckpt.sha256:
        partial.unlink()
        raise RuntimeError(
            f"{ckpt.url} has sha256 {actual}, expected {ckpt.sha256}"
        )
    partial.rename(target)
    _VERIFIED_CHECKPOINTS.add(target)
    return target


# --------------------------------------------------------------------------
# model backends
# --------------------------------------------------------------------------


def _lanczos_2x(arr: np.ndarray) -> np.ndarray:
    h, w = arr.shape[:2]
    return resize_planes(arr, (w * 2, h * 2), Image.LANCZOS)


BUILTINS: dict[str, PlaneUpscaler] = {"lanczos": _lanczos_2x}


class SpandrelModel:
    """A spandrel-loaded checkpoint, called as a native-scale PlaneUpscaler."""

    def __init__(self, path: Path, expected_scale: int) -> None:
        import spandrel
        import torch

        self._torch = torch
        torch.backends.cudnn.benchmark = False

        descriptor = spandrel.ModelLoader().load_from_file(str(path))
        if not isinstance(descriptor, spandrel.ImageModelDescriptor):
            raise RuntimeError(f"{path.name} is not a single-image model")
        if descriptor.scale != expected_scale:
            raise RuntimeError(
                f"{path.name} is {descriptor.scale}x, registry says {expected_scale}x"
            )
        if descriptor.input_channels != 3:
            raise RuntimeError(
                f"{path.name} takes {descriptor.input_channels} input channels, need 3"
            )

        self.device = self._pick_device()
        descriptor.to(self.device)
        descriptor.model.to(torch.float32)
        descriptor.eval()
        self.descriptor = descriptor

    def _pick_device(self):
        torch = self._torch
        try:
            if torch.cuda.is_available():
                torch.zeros(1, device="cuda")
                return torch.device("cuda")
        except Exception as exc:  # noqa: BLE001 - any CUDA init failure is fatal to CUDA
            log.warning("CUDA unavailable (%s), running on CPU", exc)
            return torch.device("cpu")
        log.warning("CUDA unavailable, running on CPU")
        return torch.device("cpu")

    def __call__(self, arr: np.ndarray) -> np.ndarray:
        torch = self._torch
        chw = np.ascontiguousarray(arr.transpose(2, 0, 1))
        tensor = torch.from_numpy(chw).unsqueeze(0).to(self.device)
        with torch.inference_mode():
            out = self.descriptor(tensor)
        out = out.clamp(0.0, 1.0)[0].permute(1, 2, 0).to(torch.float32).cpu().numpy()
        return np.ascontiguousarray(out)

    def is_oom(self, exc: BaseException) -> bool:
        torch = self._torch
        if isinstance(exc, torch.cuda.OutOfMemoryError):
            return True
        return isinstance(exc, RuntimeError) and "out of memory" in str(exc).lower()

    def free_memory(self) -> None:
        if self.device.type == "cuda":
            self._torch.cuda.empty_cache()


_MODEL_CACHE: dict[tuple[Path, int], SpandrelModel] = {}


def load_model(path: Path, scale: int) -> SpandrelModel:
    """Return the `SpandrelModel` for a checkpoint, loading it at most once.

    Every ML upscaler is requested twice — once for the colour planes and once
    for the alpha plane, which differ only in the 4x->2x kernel — so without
    this each checkpoint is parsed and uploaded to the device twice.
    """
    key = (path, scale)
    model = _MODEL_CACHE.get(key)
    if model is None:
        model = SpandrelModel(path, scale)
        _MODEL_CACHE[key] = model
    return model


# --------------------------------------------------------------------------
# assembling a PlaneUpscaler
# --------------------------------------------------------------------------


def _run_with_oom_fallback(
    run: PlaneRunner,
    arr: np.ndarray,
    scale: int,
    resample: int,
    is_oom: Callable[[BaseException], bool],
    free_memory: Callable[[], None] = lambda: None,
    max_tile: int = MAX_TILE,
    overlap: int = TILE_OVERLAP,
) -> np.ndarray:
    """Whole-image inference, falling back to halving tiles on CUDA OOM.

    ``is_oom`` classifies an exception as an out-of-memory condition; anything
    else propagates. The ladder parameters are arguments so the retry path can
    be driven with small planes in tests.
    """
    if max_tile <= 2 * overlap:
        raise ValueError(f"max tile {max_tile} is not larger than 2x overlap {overlap}")
    try:
        return run_padded(run, arr, scale, out_scale=2, resample=resample)
    except Exception as exc:  # noqa: BLE001 - re-raised unless it is an OOM
        if not is_oom(exc):
            raise
        free_memory()

    tile, failed_at = max_tile, "whole-image inference"
    while tile > 2 * overlap:
        log.warning("CUDA OOM on %s, retrying with %d px tiles", failed_at, tile)
        try:
            return run_padded(
                run,
                arr,
                scale,
                tile=tile,
                overlap=overlap,
                out_scale=2,
                resample=resample,
            )
        except Exception as exc:  # noqa: BLE001 - re-raised unless it is an OOM
            if not is_oom(exc):
                raise
            free_memory()
            tile, failed_at = tile // 2, f"{tile} px tiles"
    raise RuntimeError(
        f"CUDA OOM at every tile size down to {tile * 2} px, the smallest "
        f"larger than 2x the {overlap} px overlap"
    )


def build_upscaler(
    run: PlaneRunner,
    scale: int,
    *,
    alpha_plane: bool = False,
    is_oom: Callable[[BaseException], bool] | None = None,
    free_memory: Callable[[], None] = lambda: None,
) -> PlaneUpscaler:
    """Wrap a native-``scale`` runner into an exact-2x, clamped PlaneUpscaler.

    Passing ``is_oom`` enables the OOM-fallback tiling path for runners that can
    exhaust VRAM. Without it — classical scalers, CPU inference, test fakes —
    every run is whole-image and an exception from the runner propagates.
    """
    # 4x -> 2x with Lanczos rings alpha a few levels above zero just outside
    # every hard edge, compositing a faint coloured outline in game. Alpha
    # planes get a non-negative kernel instead.
    resample = Image.BOX if alpha_plane else Image.LANCZOS

    if is_oom is None:
        def upscale(arr: np.ndarray) -> np.ndarray:
            return run_padded(run, arr, scale, out_scale=2, resample=resample)
    else:
        def upscale(arr: np.ndarray) -> np.ndarray:
            return _run_with_oom_fallback(
                run, arr, scale, resample, is_oom, free_memory
            )

    return upscale


def get_upscaler(name: str, *, alpha_plane: bool = False) -> PlaneUpscaler:
    """Resolve a registry name to a ready-to-call exact-2x PlaneUpscaler.

    ML checkpoints download and hash-verify on first use. Pass
    ``alpha_plane=True`` when the plane being upscaled is a replicated alpha
    channel, so any 4x->2x downscale uses a non-negative kernel.
    """
    try:
        entry: Entry = REGISTRY[name]
    except KeyError:
        raise KeyError(
            f"unknown upscaler {name!r}; known: {', '.join(sorted(REGISTRY))}"
        ) from None

    if entry.builtin is not None:
        return build_upscaler(BUILTINS[entry.builtin], entry.scale, alpha_plane=alpha_plane)

    assert entry.checkpoint is not None
    model = load_model(ensure_checkpoint(entry.checkpoint), entry.scale)
    # Only CUDA runs out of VRAM; on the CPU fallback an OOM is a host
    # MemoryError that tiling would not help.
    is_oom = model.is_oom if model.device.type == "cuda" else None
    return build_upscaler(
        model,
        entry.scale,
        alpha_plane=alpha_plane,
        is_oom=is_oom,
        free_memory=model.free_memory,
    )
