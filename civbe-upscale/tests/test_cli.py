"""Tests for the CLI's directory guard and `batch`'s resume.

`cmd_batch`'s and `cmd_compare`'s upscaling behavior needs a real work list
and is exercised by the smoke tests recorded in the task output, not here.
What is worth pinning at this layer is that in==out is rejected before
anything is read or written, and that a second `batch` run over the same
output directory does the remaining files and only those.
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


def batch_args(in_dir, out_dir, *, redo=False):
    return argparse.Namespace(
        input_dir=str(in_dir), output_dir=str(out_dir), upscaler="lanczos", redo=redo
    )


def test_batch_resumes_past_outputs_that_already_exist(tmp_path, monkeypatch):
    in_dir, out_dir = tmp_path / "in", tmp_path / "out"
    in_dir.mkdir()
    for name in ("a.png", "b.png", "c.png"):
        make_rgba_png(in_dir / name)

    upscaled = []
    real_apply = cli.apply_upscaler

    def counting_apply(name, img):
        upscaled.append(name)
        return real_apply(name, img)

    monkeypatch.setattr(cli, "apply_upscaler", counting_apply)

    assert cli.cmd_batch(batch_args(in_dir, out_dir)) == 0
    assert len(upscaled) == 3

    (out_dir / "b.png").unlink()
    upscaled.clear()
    assert cli.cmd_batch(batch_args(in_dir, out_dir)) == 0
    assert len(upscaled) == 1
    assert (out_dir / "b.png").exists()

    upscaled.clear()
    assert cli.cmd_batch(batch_args(in_dir, out_dir, redo=True)) == 0
    assert len(upscaled) == 3


def test_batch_refuses_to_resume_under_a_different_upscaler(tmp_path):
    in_dir, out_dir = tmp_path / "in", tmp_path / "out"
    in_dir.mkdir()
    make_rgba_png(in_dir / "a.png")

    assert cli.cmd_batch(batch_args(in_dir, out_dir)) == 0

    args = batch_args(in_dir, out_dir)
    args.upscaler = "lanczos-rgba"
    with pytest.raises(SystemExit, match="belongs to a different run"):
        cli.cmd_batch(args)
