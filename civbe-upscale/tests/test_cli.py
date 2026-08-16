"""Tests for the CLI's input/output directory guard.

`cmd_batch`'s and `cmd_compare`'s other behavior needs a real work list and is
exercised by the smoke tests recorded in the task output, not here -- the
only thing worth pinning at this layer is that in==out is rejected before
anything is read or written.
"""

from __future__ import annotations

import argparse

import numpy as np
import pytest
from PIL import Image

from civbe_upscale import cli


def make_rgba_png(path):
    rng = np.random.default_rng(1)
    arr = np.empty((4, 4, 4), dtype=np.uint8)
    arr[:, :, :3] = rng.integers(0, 256, (4, 4, 3), dtype=np.uint8)
    arr[:, :, 3] = 255
    Image.fromarray(arr, mode="RGBA").save(path)


@pytest.mark.parametrize(
    "make_args",
    [
        lambda d: argparse.Namespace(
            input_dir=str(d), output_dir=str(d), upscaler="lanczos"
        ),
        lambda d: argparse.Namespace(
            input_dir=str(d), output_dir=str(d), upscalers="lanczos", crops=[]
        ),
    ],
    ids=["batch", "compare"],
)
def test_in_dir_equal_to_out_dir_is_rejected(tmp_path, make_args):
    src = tmp_path / "in.png"
    make_rgba_png(src)
    before = src.read_bytes()

    func = cli.cmd_batch if "upscaler" in vars(make_args(tmp_path)) else cli.cmd_compare
    args = make_args(tmp_path)

    with pytest.raises(SystemExit, match="output directory must differ from input directory"):
        func(args)

    # Nothing written: the source file is untouched and no other file appeared.
    assert src.read_bytes() == before
    assert [p.name for p in tmp_path.iterdir()] == ["in.png"]


def test_in_dir_equal_to_out_dir_is_rejected_with_dot_path(tmp_path, monkeypatch):
    """Resolved-path equality, not string equality: `.` vs the same absolute path."""
    src = tmp_path / "in.png"
    make_rgba_png(src)

    monkeypatch.chdir(tmp_path)
    args = argparse.Namespace(input_dir=".", output_dir=str(tmp_path), upscaler="lanczos")

    with pytest.raises(SystemExit, match="output directory must differ from input directory"):
        cli.cmd_batch(args)

    assert [p.name for p in tmp_path.iterdir()] == ["in.png"]
