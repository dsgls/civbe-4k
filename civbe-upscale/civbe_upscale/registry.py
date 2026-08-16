"""The upscaler registry: name -> entry.

Names are filename-safe because they appear in ``<inputname>-<upscaler>.png``
output from compare mode. Restoration-only (native 1x) models are not admitted.

Adding an ML model is one entry: spandrel auto-detects the architecture, so
only the URL, the SHA-256 and the native scale are needed. Hashes were taken
from the exact bytes served by the URLs below.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Checkpoint:
    """A downloadable model file, cached under ``models/`` and hash-verified."""

    url: str
    sha256: str

    @property
    def filename(self) -> str:
        return self.url.rsplit("/", 1)[-1]


@dataclass(frozen=True)
class Entry:
    """One selectable upscaler.

    Exactly one of ``checkpoint`` (spandrel-loaded ML model) and ``builtin``
    (name of a classical scaler implemented in the engine) is set.

    ``scale`` is the upscaler's *native* scale; the engine normalizes every
    output to exactly 2x. ``bypass_alpha`` marks an entry that must not go
    through the two-plane alpha pipeline.
    """

    scale: int
    description: str
    checkpoint: Checkpoint | None = None
    builtin: str | None = None
    bypass_alpha: bool = False

    def __post_init__(self) -> None:
        if (self.checkpoint is None) == (self.builtin is None):
            raise ValueError("entry needs exactly one of checkpoint / builtin")
        if self.scale < 2:
            raise ValueError("restoration-only (1x) upscalers are not admitted")


REGISTRY: dict[str, Entry] = {
    # --- general Real-ESRGAN family ---------------------------------------
    "realesrgan-x4plus": Entry(
        scale=4,
        description="Real-ESRGAN x4plus (RRDBNet), the general-purpose baseline",
        checkpoint=Checkpoint(
            url="https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth",
            sha256="4fa0d38905f75ac06eb49a7951b426670021be3018265fd191d2125df9d682f1",
        ),
    ),
    "realesrgan-x2plus": Entry(
        scale=2,
        description="Real-ESRGAN x2plus (RRDBNet), native 2x so no downscale step",
        checkpoint=Checkpoint(
            url="https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x2plus.pth",
            sha256="49fafd45f8fd7aa8d31ab2a22d14d91b536c34494a5cfe31eb5d89c2fa266abb",
        ),
    ),
    "realesr-compact": Entry(
        scale=4,
        description="realesr-general-x4v3 (SRVGGNetCompact), lighter and less GAN-happy",
        checkpoint=Checkpoint(
            url="https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesr-general-x4v3.pth",
            sha256="8dc7edb9ac80ccdc30c3a5dca6616509367f05fbc184ad95b731f05bece96292",
        ),
    ),
    # --- transformer ------------------------------------------------------
    "swinir-x4": Entry(
        scale=4,
        description="SwinIR-M real-SR GAN, window attention",
        checkpoint=Checkpoint(
            url="https://github.com/JingyunLiang/SwinIR/releases/download/v0.0/003_realSR_BSRGAN_DFO_s64w8_SwinIR-M_x4_GAN.pth",
            sha256="b9afb61e65e04eb7f8aba5095d070bbe9af28df76acd0c9405aeb33b814bcfc6",
        ),
    ),
    "dat2-gametex": Entry(
        scale=4,
        description="PBRify_UpscalerDAT2 V1 (DAT2 transformer) trained on game textures",
        checkpoint=Checkpoint(
            url="https://github.com/Kim2091/Kim2091-Models/releases/download/4x-PBRify_UpscalerDAT2_V1/4x-PBRify_UpscalerDAT2_V1.pth",
            sha256="ff133c35707986e253a9e84aae16ef0295847de41239f1eda53fbbeb0e2243b7",
        ),
    ),
    # --- community line-art / game models ---------------------------------
    "animesharp-v4": Entry(
        scale=2,
        description="2x-AnimeSharpV4 (RCAN), crisp line art and flat colour regions",
        checkpoint=Checkpoint(
            url="https://github.com/Kim2091/Kim2091-Models/releases/download/2x-AnimeSharpV4/2x-AnimeSharpV4_RCAN.safetensors",
            sha256="6470bb91d6622d6acdff81132c1a8615b961b919ce2b9a01ce993378500cfbe1",
        ),
    ),
    "realesrgan-anime6b": Entry(
        scale=4,
        description="Real-ESRGAN x4plus anime 6B, smooth-gradient counterpoint",
        checkpoint=Checkpoint(
            url="https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth",
            sha256="f872d837d3c90ed2e05227bed711af5671a6fd1c9f7d7e91c911a61f155e99da",
        ),
    ),
    # --- classical --------------------------------------------------------
    "lanczos": Entry(
        scale=2,
        description="Pillow LANCZOS through the standard two-plane alpha path",
        builtin="lanczos",
    ),
    "lanczos-rgba": Entry(
        scale=2,
        description="single-pass RGBA Pillow LANCZOS; diagnostic control for the alpha path",
        builtin="lanczos",
        bypass_alpha=True,
    ),
}
