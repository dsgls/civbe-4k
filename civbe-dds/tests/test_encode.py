"""encode.write: Image -> plain, single-level A8B8G8R8 .dds.

FTXT fields are best-effort (see the design spec's *Encoding* section) and
deliberately not pinned here.
"""
from civbe_dds.encode import write
from civbe_dds.header import HEADER_LEN, header, pixel_format


def _image(width=2, height=2, rgba=None, group=""):
    from civbe_dds.image import Image
    if rgba is None:
        rgba = bytes(range(4))[:4] * (width * height)
    return Image(width=width, height=height, rgba=rgba, group=group)


class TestHeaderFields:
    def test_written_file_parses_as_a8b8g8r8_single_level(self, tmp_path):
        p = tmp_path / "out.dds"
        write(str(p), _image(width=8, height=4))
        h = header(str(p))
        assert h.width == 8
        assert h.height == 4
        assert h.mips == 1
        assert h.bits == 32
        assert pixel_format(h) == "A8B8G8R8"

    def test_file_size_is_header_plus_tightly_packed_pixels(self, tmp_path):
        p = tmp_path / "out.dds"
        write(str(p), _image(width=5, height=3))
        assert p.stat().st_size == HEADER_LEN + 5 * 3 * 4


class TestGroupFallback:
    def test_explicit_group_overrides_image_group(self, tmp_path):
        p = tmp_path / "out.dds"
        write(str(p), _image(group="Interface Scalable"), group="Explicit")
        assert header(str(p)).group == "Explicit"

    def test_falls_back_to_image_group_when_none_given(self, tmp_path):
        p = tmp_path / "out.dds"
        write(str(p), _image(group="Interface Scalable"))
        assert header(str(p)).group == "Interface Scalable"

    def test_falls_back_to_interface_when_neither_given(self, tmp_path):
        p = tmp_path / "out.dds"
        write(str(p), _image(group=""))
        assert header(str(p)).group == "Interface"


class TestPixelBytes:
    def test_pixels_are_written_verbatim_in_r_g_b_a_order(self, tmp_path):
        # Four distinct channel values per texel makes a byte-order bug
        # visible as a wrong byte at a specific offset, not just a wrong
        # colour.
        rgba = bytes([10, 20, 30, 40, 50, 60, 70, 80])
        p = tmp_path / "out.dds"
        write(str(p), _image(width=2, height=1, rgba=rgba))
        on_disk = p.read_bytes()
        assert on_disk[HEADER_LEN:] == rgba

    def test_pixel_bytes_are_not_reordered_for_multiple_rows(self, tmp_path):
        rgba = bytes(range(4 * 4 * 4))  # 4x4, distinct byte per channel slot
        p = tmp_path / "out.dds"
        write(str(p), _image(width=4, height=4, rgba=rgba))
        on_disk = p.read_bytes()
        assert on_disk[HEADER_LEN:] == rgba
