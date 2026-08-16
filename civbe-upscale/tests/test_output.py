"""Tests for the atomic write and the run manifest resuming depends on."""

from __future__ import annotations

import json

import numpy as np
import pytest
from PIL import Image

from civbe_upscale import output


def rgba(value=200):
    arr = np.full((4, 4, 4), value, dtype=np.uint8)
    return Image.fromarray(arr, mode="RGBA")


def test_save_atomic_writes_a_readable_png_and_leaves_no_part_file(tmp_path):
    target = tmp_path / "out.png"
    output.save_atomic(rgba(), target)

    with Image.open(target) as img:
        assert img.mode == "RGBA"
        assert img.size == (4, 4)
    assert [p.name for p in tmp_path.iterdir()] == ["out.png"]


def test_a_failed_save_leaves_the_target_missing(tmp_path, monkeypatch):
    """The invariant resume rests on: a present output file is a complete one."""
    target = tmp_path / "out.png"

    class Exploding:
        def save(self, path, format):  # noqa: A002 - matches PIL's signature
            path.write_bytes(b"\x89PNG half")
            raise OSError("disk full")

    with pytest.raises(OSError, match="disk full"):
        output.save_atomic(Exploding(), target)

    assert not target.exists()
    assert (tmp_path / "out.png.part").exists()


def test_save_atomic_replaces_an_existing_output(tmp_path):
    target = tmp_path / "out.png"
    output.save_atomic(rgba(10), target)
    output.save_atomic(rgba(250), target)

    with Image.open(target) as img:
        assert np.asarray(img)[0, 0, 0] == 250


def test_manifest_is_written_on_a_first_run_and_accepted_on_resume(tmp_path):
    fields = {"mode": "batch", "input_dir": "/in", "upscaler": "lanczos"}
    output.check_manifest(tmp_path, fields, redo=False)

    recorded = json.loads((tmp_path / output.MANIFEST_NAME).read_text(encoding="utf-8"))
    assert recorded == fields

    output.check_manifest(tmp_path, fields, redo=False)  # resume: no error


def test_resuming_with_a_different_upscaler_is_rejected(tmp_path):
    output.check_manifest(
        tmp_path, {"mode": "batch", "upscaler": "lanczos"}, redo=False
    )

    with pytest.raises(SystemExit, match="belongs to a different run"):
        output.check_manifest(
            tmp_path, {"mode": "batch", "upscaler": "dat2-gametex"}, redo=False
        )


def test_redo_overwrites_a_mismatched_manifest(tmp_path):
    output.check_manifest(tmp_path, {"mode": "batch", "upscaler": "lanczos"}, redo=False)
    output.check_manifest(tmp_path, {"mode": "batch", "upscaler": "swinir-x4"}, redo=True)

    recorded = json.loads((tmp_path / output.MANIFEST_NAME).read_text(encoding="utf-8"))
    assert recorded["upscaler"] == "swinir-x4"


def test_pngs_without_a_manifest_are_refused(tmp_path):
    output.save_atomic(rgba(), tmp_path / "stray.png")

    with pytest.raises(SystemExit, match="no .civbe-upscale-run.json"):
        output.check_manifest(tmp_path, {"mode": "batch"}, redo=False)

    # --redo adopts the directory instead of refusing it.
    output.check_manifest(tmp_path, {"mode": "batch"}, redo=True)
    assert (tmp_path / output.MANIFEST_NAME).exists()
