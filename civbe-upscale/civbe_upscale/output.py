"""Atomic output writes and the run manifest that makes resuming safe.

The ~500-texture production run is long enough that it will be interrupted,
so both `batch` and `compare` resume. Progress state is the set of output
files themselves: every output is written to a `.part` sibling and
`os.replace`d into place, so a file that exists is a file that finished.
There is no ledger to fall out of sync with the directory, and redoing one
texture is `rm` on it.

That only holds while the outputs in a directory all came from the same run
parameters, which is what the manifest enforces.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

from PIL import Image

MANIFEST_NAME = ".civbe-upscale-run.json"


def save_atomic(img: Image.Image, path: Path) -> None:
    """Write `img` to `path` through a `.part` sibling and an atomic rename.

    An interrupted or failed save leaves the `.part` file behind and never a
    half-written `path` -- that is what lets a resume read "output exists" as
    "output is complete". The format is explicit because PIL infers it from
    the extension and `.part` means nothing to it.
    """
    partial = path.with_name(path.name + ".part")
    img.save(partial, format="PNG")
    os.replace(partial, path)


def check_manifest(output_dir: Path, fields: dict[str, str], *, redo: bool) -> None:
    """Bind `output_dir` to this run's parameters, or refuse to resume into it.

    Resuming trusts the output files already in the directory, so the
    directory has to be the one they were written for: resuming `batch` under
    a different `--upscaler` would otherwise blend two upscalers' output into
    one set with nothing to tell them apart. A directory holding PNGs but no
    manifest is refused for the same reason -- their provenance is unknown.

    `--redo` rewrites every output, so provenance stops mattering and the
    manifest is simply replaced.

    `output_dir` must already exist.
    """
    path = output_dir / MANIFEST_NAME
    if not redo:
        if path.exists():
            recorded = json.loads(path.read_text(encoding="utf-8"))
            mismatch = [
                f"  {k}: directory has {recorded.get(k)!r}, this run has {v!r}"
                for k, v in fields.items()
                if recorded.get(k) != v
            ]
            if mismatch:
                raise SystemExit(
                    "\n".join(
                        [
                            f"{output_dir} belongs to a different run:",
                            *mismatch,
                            "use a different output directory, or pass --redo to overwrite it",
                        ]
                    )
                )
            return
        if any(output_dir.glob("*.png")):
            raise SystemExit(
                f"{output_dir} holds PNGs but no {MANIFEST_NAME}, so it cannot be "
                "resumed safely; empty the directory, or pass --redo to overwrite it"
            )
    path.write_text(json.dumps(fields, indent=2) + "\n", encoding="utf-8")
