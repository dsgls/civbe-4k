"""DDS header parse/build round-trip, pixel-format naming and channel order."""
import struct

import pytest

from civbe_dds.header import (
    DDPF_FOURCC, DDPF_LUMINANCE, DDS_MAGIC, HEADER_LEN, DdsHeader,
    UnrecognizedPixelFormatError, build_header, channel_order, header,
    pixel_format,
)


def _raw_header(width=4, height=4, mips=1, pfflags=0, fourcc=b"\0\0\0\0",
                 bits=32, rmask=0xff, caps2=0, ftxt=None, tag=None,
                 reserved2=b"\0\0\0\0"):
    """Hand-build 128 raw header bytes, bypassing build_header, so tests can
    hit shapes build_header never produces (missing FTXT, junk after the
    usage name)."""
    d = bytearray(HEADER_LEN)
    d[0:4] = DDS_MAGIC
    struct.pack_into("<I", d, 4, 124)
    struct.pack_into("<II", d, 12, height, width)
    struct.pack_into("<I", d, 28, mips)
    struct.pack_into("<I", d, 80, pfflags)
    d[84:88] = fourcc
    struct.pack_into("<I", d, 88, bits)
    struct.pack_into("<I", d, 92, rmask)
    struct.pack_into("<I", d, 112, caps2)
    if ftxt is not None:
        d[32:36] = b"FTXT"
        d[36:76] = ftxt.ljust(40, b"\0")[:40]
    if tag is not None:
        d[116:124] = tag.ljust(8, b"\0")[:8]
    d[124:128] = reserved2
    return bytes(d)


class TestParse:
    def test_parses_dimensions_and_mips(self, tmp_path):
        p = tmp_path / "t.dds"
        p.write_bytes(_raw_header(width=64, height=32, mips=3))
        h = header(str(p))
        assert h.width == 64 and h.height == 32 and h.mips == 3

    def test_group_and_tag_read_to_first_nul(self, tmp_path):
        p = tmp_path / "t.dds"
        p.write_bytes(_raw_header(ftxt=b"Interface\0", tag=b"COLOR\0\0\0"))
        h = header(str(p))
        assert h.group == "Interface"
        assert h.tag == "COLOR"

    def test_junk_trailing_the_usage_name_is_ignored(self, tmp_path):
        # 21 forgeui_* files carry uninitialized memory after the NUL.
        junk = b"Interface\0" + b"\xff\xfe\x01garbage-pointer-bytes"
        p = tmp_path / "t.dds"
        p.write_bytes(_raw_header(ftxt=junk[:40], tag=b"COLOR\0\0\0"))
        h = header(str(p))
        assert h.group == "Interface"

    def test_no_ftxt_gives_empty_group_and_tag(self, tmp_path):
        # 8 stock textures ship with no FTXT block at all.
        p = tmp_path / "t.dds"
        p.write_bytes(_raw_header(ftxt=None, tag=None))
        h = header(str(p))
        assert h.group == ""
        assert h.tag == ""

    def test_non_dds_file_returns_none(self, tmp_path):
        p = tmp_path / "t.dds"
        p.write_bytes(b"not a dds" + b"\0" * 128)
        assert header(str(p)) is None

    def test_truncated_file_returns_none(self, tmp_path):
        p = tmp_path / "t.dds"
        p.write_bytes(DDS_MAGIC + b"\0" * 10)
        assert header(str(p)) is None


class TestBuildParseRoundTrip:
    def test_round_trips_dimensions_and_group(self, tmp_path):
        raw = build_header(128, 64, group="Interface Scalable")
        p = tmp_path / "t.dds"
        p.write_bytes(raw)
        h = header(str(p))
        assert h.width == 128
        assert h.height == 64
        assert h.mips == 1
        assert h.group == "Interface Scalable"
        assert h.tag == "COLOR"

    def test_default_group_is_interface(self, tmp_path):
        p = tmp_path / "t.dds"
        p.write_bytes(build_header(4, 4))
        assert header(str(p)).group == "Interface"

    def test_built_header_is_a8b8g8r8_with_alpha(self, tmp_path):
        p = tmp_path / "t.dds"
        p.write_bytes(build_header(4, 4))
        h = header(str(p))
        assert h.bits == 32
        assert h.rmask == 0x000000ff
        assert pixel_format(h) == "A8B8G8R8"

    def test_built_header_is_128_bytes(self):
        assert len(build_header(4, 4)) == HEADER_LEN


class TestPixelFormat:
    def test_a8b8g8r8(self):
        h = DdsHeader(4, 4, 1, 0, b"\0\0\0\0", 32, 0xff, 0, "", "")
        assert pixel_format(h) == "A8B8G8R8"

    def test_a8r8g8b8(self):
        h = DdsHeader(4, 4, 1, 0, b"\0\0\0\0", 32, 0xff0000, 0, "", "")
        assert pixel_format(h) == "A8R8G8B8"

    def test_unrecognized_32bit_mask_is_a_display_placeholder(self):
        h = DdsHeader(4, 4, 1, 0, b"\0\0\0\0", 32, 0x0000ff00, 0, "", "")
        assert pixel_format(h) == "?"

    def test_luminance(self):
        h = DdsHeader(4, 4, 1, DDPF_LUMINANCE, b"\0\0\0\0", 8, 0xff, 0, "", "")
        assert pixel_format(h) == "L8"
        h16 = DdsHeader(4, 4, 1, DDPF_LUMINANCE, b"\0\0\0\0", 16, 0xffff, 0, "", "")
        assert pixel_format(h16) == "L16"

    def test_fourcc_dxt(self):
        h = DdsHeader(4, 4, 1, DDPF_FOURCC, b"DXT1", 0, 0, 0, "", "")
        assert pixel_format(h) == "DXT1"

    def test_fourcc_numeric_d3dfmt(self):
        h = DdsHeader(4, 4, 1, DDPF_FOURCC, struct.pack("<I", 114), 0, 0, 0, "", "")
        assert pixel_format(h) == "D3DFMT#114"


class TestChannelOrder:
    def test_rgba_order(self):
        h = DdsHeader(4, 4, 1, 0, b"\0\0\0\0", 32, 0xff, 0, "", "")
        assert channel_order(h) == (0, 1, 2, 3)

    def test_bgra_order(self):
        h = DdsHeader(4, 4, 1, 0, b"\0\0\0\0", 32, 0xff0000, 0, "", "")
        assert channel_order(h) == (2, 1, 0, 3)

    def test_unrecognized_mask_raises_rather_than_guessing(self):
        h = DdsHeader(4, 4, 1, 0, b"\0\0\0\0", 32, 0x0000ff00, 0, "", "")
        with pytest.raises(UnrecognizedPixelFormatError):
            channel_order(h)
