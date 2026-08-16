"""The re-exported public surface: import civbe_dds; civbe_dds.read(...).

Nothing else in the suite imports the package top-level -- every other test
imports submodules directly -- so this is the only coverage that __init__.py
actually re-exports what it claims to, under the names it claims to.
"""
import civbe_dds


def test_reexports_the_documented_names():
    assert civbe_dds.Image is not None
    assert civbe_dds.read is not None
    assert civbe_dds.write is not None
    assert civbe_dds.header is not None
    assert civbe_dds.read_png is not None
    assert civbe_dds.write_png is not None


def test_read_and_write_round_trip_through_the_top_level_import(tmp_path):
    img = civbe_dds.Image(width=2, height=1, rgba=bytes(range(8)), group="Interface")
    p = tmp_path / "t.dds"
    civbe_dds.write(str(p), img)
    assert civbe_dds.read(str(p)) == img


def test_header_is_reachable_from_the_top_level_import(tmp_path):
    img = civbe_dds.Image(width=1, height=1, rgba=bytes(4), group="")
    p = tmp_path / "t.dds"
    civbe_dds.write(str(p), img)
    hdr = civbe_dds.header(str(p))
    assert (hdr.width, hdr.height) == (1, 1)


def test_read_png_and_write_png_round_trip_through_the_top_level_import(tmp_path):
    img = civbe_dds.Image(width=2, height=1, rgba=bytes(range(8)), group="")
    p = tmp_path / "t.png"
    civbe_dds.write_png(str(p), img)
    assert civbe_dds.read_png(str(p)).rgba == img.rgba
