"""decode.read: dispatch any supported .dds to a level-0 Image."""
import struct

import pytest

from civbe_dds.decode import UnsupportedFormatError, read
from civbe_dds.dxt import BLOCK_BYTES
from civbe_dds.encode import write
from civbe_dds.header import (
    DDPF_ALPHAPIXELS, DDPF_FOURCC, DDPF_LUMINANCE, DDPF_RGB, DDS_MAGIC,
    DDSCAPS2_CUBEMAP, HEADER_LEN,
)
from civbe_dds.image import Image


def _raw_header(width, height, *, pfflags=0, fourcc=b"\0\0\0\0", bits=32,
                 rmask=0xff, caps2=0, group=None, tag=None):
    """Hand-build 128 raw header bytes -- full control over the fields
    decode.read dispatches on. Mirrors test_header.py's and test_pair.py's
    helpers."""
    d = bytearray(HEADER_LEN)
    d[0:4] = DDS_MAGIC
    struct.pack_into("<I", d, 4, 124)
    struct.pack_into("<II", d, 12, height, width)
    struct.pack_into("<I", d, 28, 1)              # mips
    struct.pack_into("<I", d, 80, pfflags)
    d[84:88] = fourcc
    struct.pack_into("<I", d, 88, bits)
    struct.pack_into("<I", d, 92, rmask)
    struct.pack_into("<I", d, 112, caps2)
    if group is not None or tag is not None:
        d[32:36] = b"FTXT"
        d[36:76] = (group or b"").ljust(40, b"\0")[:40]
        d[116:124] = (tag or b"").ljust(8, b"\0")[:8]
    return bytes(d)


def _write_dds(tmp_path, name, raw):
    p = tmp_path / ("%s.dds" % name)
    p.write_bytes(raw)
    return str(p)


class TestDispatch32Bit:
    def test_a8b8g8r8_bytes_pass_through_as_rgba(self, tmp_path):
        # rmask 0xff: bytes on disk are already R,G,B,A.
        rgba = bytes([10, 20, 30, 40, 50, 60, 70, 80])
        raw = _raw_header(2, 1, pfflags=DDPF_RGB | DDPF_ALPHAPIXELS,
                           bits=32, rmask=0xff) + rgba
        p = _write_dds(tmp_path, "t", raw)
        img = read(p)
        assert (img.width, img.height) == (2, 1)
        assert img.rgba == rgba

    def test_a8r8g8b8_bytes_swap_to_rgba(self, tmp_path):
        # rmask 0xff0000: bytes on disk are B,G,R,A. Expected RGBA computed
        # independently of decode.py's own swap logic.
        on_disk = bytes([30, 20, 10, 40, 70, 60, 50, 80])   # B,G,R,A x2
        expected_rgba = bytes([10, 20, 30, 40, 50, 60, 70, 80])
        raw = _raw_header(2, 1, pfflags=DDPF_RGB | DDPF_ALPHAPIXELS,
                           bits=32, rmask=0xff0000) + on_disk
        p = _write_dds(tmp_path, "t", raw)
        img = read(p)
        assert img.rgba == expected_rgba

    def test_both_orders_agree_on_the_same_colour(self, tmp_path):
        colour = (10, 20, 30, 40)
        r, g, b, a = colour
        rgba_disk = bytes(colour)
        bgra_disk = bytes((b, g, r, a))
        p1 = _write_dds(tmp_path, "rgba",
                         _raw_header(1, 1, pfflags=DDPF_RGB, rmask=0xff) + rgba_disk)
        p2 = _write_dds(tmp_path, "bgra",
                         _raw_header(1, 1, pfflags=DDPF_RGB, rmask=0xff0000) + bgra_disk)
        assert read(p1).rgba == read(p2).rgba == bytes(colour)

    def test_unrecognized_mask_raises(self, tmp_path):
        raw = _raw_header(1, 1, pfflags=DDPF_RGB, bits=32, rmask=0x0000ff00) \
            + bytes(4)
        p = _write_dds(tmp_path, "t", raw)
        with pytest.raises(ValueError):
            read(p)

    def test_group_is_carried_from_ftxt(self, tmp_path):
        raw = _raw_header(1, 1, pfflags=DDPF_RGB, rmask=0xff,
                           group=b"Interface Scalable\0", tag=b"COLOR\0\0\0") + bytes(4)
        p = _write_dds(tmp_path, "t", raw)
        assert read(p).group == "Interface Scalable"


class TestDispatchLuminance:
    def test_l8_replicates_grey_with_opaque_alpha(self, tmp_path):
        raw = _raw_header(2, 1, pfflags=DDPF_LUMINANCE, bits=8, rmask=0xff) \
            + bytes([100, 200])
        p = _write_dds(tmp_path, "t", raw)
        img = read(p)
        assert img.rgba == bytes([100, 100, 100, 255, 200, 200, 200, 255])

    def test_l16_reduces_by_shifting_out_the_low_byte(self, tmp_path):
        # v >> 8 on a little-endian 16-bit sample is just the high byte.
        samples = struct.pack("<2H", 0x1234, 0xABCD)
        raw = _raw_header(2, 1, pfflags=DDPF_LUMINANCE, bits=16, rmask=0xffff) \
            + samples
        p = _write_dds(tmp_path, "t", raw)
        img = read(p)
        assert img.rgba == bytes([0x12, 0x12, 0x12, 255, 0xAB, 0xAB, 0xAB, 255])


class TestDispatchDxt:
    def test_dxt1_delegates_to_dxt_decode(self, tmp_path):
        # One 4x4 opaque DXT1 block: c0=c1=0xFFFF (white, since c0<=c1 would
        # normally trigger 3-colour mode, so use c0 > c1 for 4-colour mode
        # with all indices 0 -> solid colour 0).
        c0, c1 = 0xFFFF, 0x0000
        block = struct.pack("<HHI", c0, c1, 0)   # all texels index 0 -> c0
        raw = _raw_header(4, 4, pfflags=DDPF_FOURCC, fourcc=b"DXT1") + block
        p = _write_dds(tmp_path, "t", raw)
        img = read(p)
        assert (img.width, img.height) == (4, 4)
        assert img.rgba == bytes([255, 255, 255, 255]) * 16

    def test_dxt_reads_exactly_the_declared_block_bytes(self, tmp_path):
        # A non-multiple-of-4 image still needs one full 4x4 block of data;
        # this pins that decode.py sizes its read off the padded grid, not
        # the raw declared dimensions.
        c0, c1 = 0xFFFF, 0x0000
        block = struct.pack("<HHI", c0, c1, 0)
        raw = _raw_header(3, 2, pfflags=DDPF_FOURCC, fourcc=b"DXT1") + block
        p = _write_dds(tmp_path, "t", raw)
        img = read(p)
        assert (img.width, img.height) == (3, 2)
        assert img.rgba == bytes([255, 255, 255, 255]) * (3 * 2)

    def test_every_fourcc_in_block_bytes_dispatches(self, tmp_path):
        # DXT2-5 all decode without raising -- exercising the dispatch, not
        # re-testing the codecs themselves (that's dxt.py's job).
        for fourcc, size in BLOCK_BYTES.items():
            raw = _raw_header(4, 4, pfflags=DDPF_FOURCC, fourcc=fourcc) \
                + bytes(size)
            p = _write_dds(tmp_path, fourcc.decode("latin1"), raw)
            img = read(p)
            assert (img.width, img.height) == (4, 4)


class TestUnsupportedFormats:
    def test_fic_fourcc_raises_named_error(self, tmp_path):
        raw = _raw_header(4, 4, pfflags=DDPF_FOURCC,
                           fourcc=struct.pack("<I", 114))
        p = _write_dds(tmp_path, "t", raw)
        with pytest.raises(UnsupportedFormatError):
            read(p)

    def test_other_fourcc_raises_named_error_not_a_struct_failure(self, tmp_path):
        raw = _raw_header(4, 4, pfflags=DDPF_FOURCC, fourcc=b"ZZZZ")
        p = _write_dds(tmp_path, "t", raw)
        with pytest.raises(UnsupportedFormatError):
            read(p)

    def test_non_dds_file_raises(self, tmp_path):
        p = tmp_path / "t.dds"
        p.write_bytes(b"not a dds" + b"\0" * 128)
        with pytest.raises(ValueError):
            read(str(p))


class TestCubemap:
    def test_decodes_face_0_and_warns_on_stderr(self, tmp_path, capsys):
        rgba = bytes([1, 2, 3, 4])
        raw = _raw_header(1, 1, pfflags=DDPF_RGB, bits=32, rmask=0xff,
                           caps2=DDSCAPS2_CUBEMAP) + rgba
        p = _write_dds(tmp_path, "t", raw)
        img = read(p)
        assert img.rgba == rgba
        assert "cubemap" in capsys.readouterr().err.lower()

    def test_non_cubemap_flag_bits_dont_trigger_the_warning(self, tmp_path, capsys):
        # caps2 has other bits set but not DDSCAPS2_CUBEMAP (0x200).
        rgba = bytes([1, 2, 3, 4])
        raw = _raw_header(1, 1, pfflags=DDPF_RGB, bits=32, rmask=0xff,
                           caps2=0x400) + rgba
        p = _write_dds(tmp_path, "t", raw)
        read(p)
        assert capsys.readouterr().err == ""


class TestPairDispatch:
    def test_pair_delegates_to_decode_pair(self, tmp_path):
        # Minimal N=1 dictionary/index pair, built the same way test_pair.py
        # does, to confirm read() routes to pair.decode_pair rather than
        # trying to parse the dictionary as a plain texture.
        colour = (9, 8, 7, 255)
        dic_hdr = _raw_header(1, 1, pfflags=0, bits=32, rmask=0xff,
                               group=b"Interface\0", tag=b"BC001\0\0")
        dic = dic_hdr + bytes(colour)
        idx_hdr = _raw_header(1, 1, pfflags=DDPF_LUMINANCE, bits=8, rmask=0xff)
        idx = idx_hdr + bytes([0])
        dds = tmp_path / "t.dds"
        dds.write_bytes(dic)
        (tmp_path / "t-index.dds").write_bytes(idx)

        img = read(str(dds))

        assert (img.width, img.height) == (1, 1)
        assert img.rgba == bytes(colour)
        assert img.group == "Interface"


class TestRoundTrip:
    def test_decode_of_encoded_image_equals_original(self, tmp_path):
        w, h = 3, 2
        rgba = bytes((i * 7 + 3) % 256 for i in range(w * h * 4))
        img = Image(width=w, height=h, rgba=rgba, group="Interface Scalable")
        p = tmp_path / "out.dds"
        write(str(p), img)
        assert read(str(p)) == img

    def test_encode_of_decoded_32bit_source_rereads_to_the_same_rgba(self, tmp_path):
        # Independent of decode's own logic: build a BGRA-on-disk file from
        # known RGBA values, decode it, re-encode, and check the bytes match
        # the RGBA we started from -- not each other.
        expected_rgba = bytes([1, 2, 3, 4, 5, 6, 7, 8])
        on_disk = bytes([3, 2, 1, 4, 7, 6, 5, 8])   # B,G,R,A order
        raw = _raw_header(2, 1, pfflags=DDPF_RGB, bits=32, rmask=0xff0000) + on_disk
        src = _write_dds(tmp_path, "src", raw)

        decoded = read(src)
        assert decoded.rgba == expected_rgba

        out = tmp_path / "roundtrip.dds"
        write(str(out), decoded)
        assert read(str(out)).rgba == expected_rgba

    def test_encode_of_decoded_pair_source_rereads_to_the_same_rgba(self, tmp_path):
        n = 2
        colours = [(1, 2, 3, 255), (11, 12, 13, 255), (21, 22, 23, 255), (31, 32, 33, 255)]
        cols = 2
        pw, ph = 4, 4
        pixels = bytearray(pw * ph * 4)
        for k, colour in enumerate(colours):
            sx, sy = (k % cols) * n, (k // cols) * n
            for row in range(n):
                for col in range(n):
                    off = ((sy + row) * pw + sx + col) * 4
                    pixels[off:off + 4] = bytes(colour)
        dic = _raw_header(pw, ph, pfflags=0, bits=32, rmask=0xff,
                           group=b"Interface\0", tag=b"BC002\0\0") + bytes(pixels)
        idx = _raw_header(2, 2, pfflags=DDPF_LUMINANCE, bits=8, rmask=0xff) \
            + bytes([3, 0, 2, 1])
        dds = tmp_path / "t.dds"
        dds.write_bytes(dic)
        (tmp_path / "t-index.dds").write_bytes(idx)

        decoded = read(str(dds))
        out = tmp_path / "roundtrip.dds"
        write(str(out), decoded)
        reread = read(str(out))

        assert reread.rgba == decoded.rgba
        assert (reread.width, reread.height) == (decoded.width, decoded.height)
