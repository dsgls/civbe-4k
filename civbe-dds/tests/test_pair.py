"""Dictionary/index pair detection and decode."""
import struct

import pytest

from civbe_dds.header import DDS_MAGIC, HEADER_LEN
from civbe_dds.pair import NotDictionaryCodedError, decode_pair, index_path, is_pair


def _raw_header(width, height, *, pfflags=0, bits=32, rmask=0xff, tag=None,
                 group=None):
    """Hand-build 128 raw header bytes for a dictionary or an index file.

    Mirrors test_header.py's helper: full control over the fields decode_pair
    reads (tag, bit depth, R mask) that build_header's fixed A8B8G8R8/COLOR
    shape can't produce.
    """
    d = bytearray(HEADER_LEN)
    d[0:4] = DDS_MAGIC
    struct.pack_into("<I", d, 4, 124)
    struct.pack_into("<II", d, 12, height, width)
    struct.pack_into("<I", d, 28, 1)              # mips
    struct.pack_into("<I", d, 80, pfflags)
    struct.pack_into("<I", d, 88, bits)
    struct.pack_into("<I", d, 92, rmask)
    if group is not None or tag is not None:
        d[32:36] = b"FTXT"
        d[36:76] = (group or b"").ljust(40, b"\0")[:40]
        d[116:124] = (tag or b"").ljust(8, b"\0")[:8]
    return bytes(d)


def _dict_bytes(width, height, n, tile_colours, rmask=0xff, group=b"Interface\0"):
    """A dictionary file: width x height RGB(A) pixels, `cols = width // n`
    tile slots per row, tile k filled solid with tile_colours[k]. `tile_colours`
    holds (r, g, b, a) tuples; stored in dictionary byte order per `rmask`
    (A8B8G8R8 stores r,g,b,a verbatim; A8R8G8B8 stores b,g,r,a)."""
    tag = ("BC0%02X" % n).encode("latin1")
    hdr = _raw_header(width, height, bits=32, rmask=rmask, tag=tag, group=group)
    cols = width // n
    pixels = bytearray(width * height * 4)
    for k, (r, g, b, a) in enumerate(tile_colours):
        px = (r, g, b, a) if rmask == 0xff else (b, g, r, a)
        sx, sy = (k % cols) * n, (k // cols) * n
        for row in range(n):
            for col in range(n):
                off = ((sy + row) * width + sx + col) * 4
                pixels[off:off + 4] = bytes(px)
    return hdr + bytes(pixels)


def _index_bytes(width, height, bits, keys):
    """An index file: L8 or L16 texels, row-major, holding tile numbers."""
    hdr = _raw_header(width, height, pfflags=0x20000, bits=bits,
                       rmask=0xff if bits == 8 else 0xffff, tag=b"L%d" % bits)
    body = bytes(keys) if bits == 8 else struct.pack("<%dH" % len(keys), *keys)
    return hdr + body


def _write_pair(tmp_path, name, dict_bytes, index_bytes):
    dds = tmp_path / ("%s.dds" % name)
    idx = tmp_path / ("%s-index.dds" % name)
    dds.write_bytes(dict_bytes)
    idx.write_bytes(index_bytes)
    return str(dds)


class TestIndexPath:
    def test_appends_index_suffix_before_extension(self):
        assert index_path("foo.dds") == "foo-index.dds"

    def test_handles_nested_paths(self):
        assert index_path("/a/b/foo.dds") == "/a/b/foo-index.dds"


class TestIsPair:
    def test_true_when_index_sibling_exists(self, tmp_path):
        p = _write_pair(tmp_path, "t", _dict_bytes(2, 2, 1, [(1, 2, 3, 4)]),
                         _index_bytes(1, 1, 8, [0]))
        assert is_pair(p) is True

    def test_false_when_no_sibling(self, tmp_path):
        p = tmp_path / "solo.dds"
        p.write_bytes(_dict_bytes(2, 2, 1, [(1, 2, 3, 4)]))
        assert is_pair(str(p)) is False

    def test_false_for_the_index_file_itself(self, tmp_path):
        p = _write_pair(tmp_path, "t", _dict_bytes(2, 2, 1, [(1, 2, 3, 4)]),
                         _index_bytes(1, 1, 8, [0]))
        assert is_pair(index_path(p)) is False


class TestDecodePair:
    def test_reassembles_tiles_by_index_not_by_position(self, tmp_path):
        # N=2, 4 distinct tiles in a 2x2 dictionary grid (cols=2). The index
        # deliberately scrambles the order so a positional copy (rather than
        # a lookup by k) would produce the wrong picture.
        n = 2
        colours = [(1, 2, 3, 255), (11, 12, 13, 255), (21, 22, 23, 255), (31, 32, 33, 255)]
        dic = _dict_bytes(4, 4, n, colours, group=b"Interface\0")
        idx = _index_bytes(2, 2, 8, [3, 0, 2, 1])
        p = _write_pair(tmp_path, "t", dic, idx)

        img = decode_pair(p)

        assert (img.width, img.height) == (4, 4)
        assert img.group == "Interface"

        def tile(cx, cy):
            return b"".join(
                bytes(img.rgba[((cy * n + row) * img.width + cx * n + col) * 4:
                                ((cy * n + row) * img.width + cx * n + col) * 4 + 4])
                for row in range(n) for col in range(n)
            )

        assert tile(0, 0) == bytes(colours[3]) * (n * n)
        assert tile(1, 0) == bytes(colours[0]) * (n * n)
        assert tile(0, 1) == bytes(colours[2]) * (n * n)
        assert tile(1, 1) == bytes(colours[1]) * (n * n)

    def test_tag_is_hexadecimal_bc010_means_16(self, tmp_path):
        # The nn in BC0nn is hex: BC010 is 16-pixel tiles, not 10. The
        # buttonsides shape: one 16x16 tile, 1x1 index. A decimal reading
        # would decode a 10x10 crop.
        n = 16
        colours = [(10, 20, 30, 255), (40, 50, 60, 255), (70, 80, 90, 255)]
        dic = _dict_bytes(48, 16, n, colours)
        idx = _index_bytes(3, 1, 8, [0, 1, 2])
        p = _write_pair(tmp_path, "t", dic, idx)
        assert dic[116:121] == b"BC010"

        img = decode_pair(p)

        assert (img.width, img.height) == (48, 16)
        for i, colour in enumerate(colours):
            block = img.rgba[i * n * 4:(i + 1) * n * 4]
            assert block == bytes(colour) * n

    def test_tag_is_hexadecimal_bc020_means_32(self, tmp_path):
        # BC020 (seededstartcargoselectback) is 32-pixel tiles.
        n = 32
        dic = _dict_bytes(32, 32, n, [(5, 6, 7, 255)])
        idx = _index_bytes(1, 1, 8, [0])
        p = _write_pair(tmp_path, "t", dic, idx)
        assert dic[116:121] == b"BC020"

        img = decode_pair(p)

        assert (img.width, img.height) == (32, 32)
        assert img.rgba == bytes((5, 6, 7, 255)) * (n * n)

    def test_l16_index(self, tmp_path):
        n = 1
        colours = [(i, i, i, 255) for i in range(4)]
        dic = _dict_bytes(4, 1, n, colours)
        idx = _index_bytes(2, 2, 16, [3, 1, 0, 2])
        p = _write_pair(tmp_path, "t", dic, idx)

        img = decode_pair(p)

        assert (img.width, img.height) == (2, 2)
        expected = bytes(colours[3]) + bytes(colours[1]) + bytes(colours[0]) + bytes(colours[2])
        assert img.rgba == expected

    def test_a8r8g8b8_dictionary_channel_swap(self, tmp_path):
        # All 724 stock dictionaries are A8B8G8R8; this is the only coverage
        # of the channel-swap branch. rmask 0xff0000 -> bytes stored B,G,R,A.
        n = 1
        colours = [(200, 100, 50, 255)]     # (r, g, b, a)
        dic = _dict_bytes(1, 1, n, colours, rmask=0xff0000)
        idx = _index_bytes(1, 1, 8, [0])
        p = _write_pair(tmp_path, "t", dic, idx)

        img = decode_pair(p)

        assert img.rgba == bytes(colours[0])

    def test_non_dictionary_tag_raises(self, tmp_path):
        n = 1
        dic = bytearray(_dict_bytes(1, 1, n, [(1, 2, 3, 4)]))
        # Overwrite the FTXT tag so it no longer starts with "BC".
        dic[116:124] = b"COLOR\0\0\0"
        idx = _index_bytes(1, 1, 8, [0])
        p = _write_pair(tmp_path, "t", bytes(dic), idx)

        with pytest.raises(NotDictionaryCodedError):
            decode_pair(p)

    def test_non_dds_dictionary_raises_value_error(self, tmp_path):
        dds = tmp_path / "t.dds"
        idxp = tmp_path / "t-index.dds"
        dds.write_bytes(b"not a dds" + b"\0" * 128)
        idxp.write_bytes(_index_bytes(1, 1, 8, [0]))

        with pytest.raises(ValueError):
            decode_pair(str(dds))
