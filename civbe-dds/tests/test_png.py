"""PNG read/write, including the accepted-surface rules from the design spec:
colour types 0/2/4/6, palette expansion through PLTE/tRNS, and the 16-bit
depth error."""
import struct
import zlib

import pytest

from civbe_dds.image import Image
from civbe_dds.png import PNG_MAGIC, UnsupportedPngError, read_png, write_png


def _chunk(kind, payload):
    body = kind + payload
    return struct.pack(">I", len(payload)) + body + \
        struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def _build_png(width, height, colour, depth, rows, plte=None, trns=None, interlace=0):
    """Hand-build a PNG from unfiltered scanlines (filter type 0 on every row)."""
    scanlines = b"".join(b"\0" + row for row in rows)
    chunks = [_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, depth, colour, 0, 0, interlace))]
    if plte is not None:
        chunks.append(_chunk(b"PLTE", plte))
    if trns is not None:
        chunks.append(_chunk(b"tRNS", trns))
    chunks.append(_chunk(b"IDAT", zlib.compress(scanlines, 6)))
    chunks.append(_chunk(b"IEND", b""))
    return PNG_MAGIC + b"".join(chunks)


class TestWriteReadRoundTrip:
    def test_write_then_read_preserves_pixels(self, tmp_path):
        rgba = bytes([255, 0, 0, 255, 0, 255, 0, 128, 0, 0, 255, 64, 10, 20, 30, 40])
        img = Image(width=2, height=2, rgba=rgba, group="")
        p = tmp_path / "t.png"
        write_png(str(p), img)
        out = read_png(str(p))
        assert out.width == 2
        assert out.height == 2
        assert out.rgba == rgba

    def test_written_png_has_the_standard_magic(self, tmp_path):
        p = tmp_path / "t.png"
        write_png(str(p), Image(width=1, height=1, rgba=bytes(4), group=""))
        assert p.read_bytes()[:8] == PNG_MAGIC


class TestAcceptedColourTypes:
    def test_colour_type_0_grayscale_replicates_to_rgb(self, tmp_path):
        p = tmp_path / "t.png"
        p.write_bytes(_build_png(2, 1, 0, 8, [bytes([10, 200])]))
        img = read_png(str(p))
        assert img.rgba == bytes([10, 10, 10, 255, 200, 200, 200, 255])

    def test_colour_type_2_rgb_gets_opaque_alpha(self, tmp_path):
        p = tmp_path / "t.png"
        p.write_bytes(_build_png(2, 1, 2, 8, [bytes([1, 2, 3, 4, 5, 6])]))
        img = read_png(str(p))
        assert img.rgba == bytes([1, 2, 3, 255, 4, 5, 6, 255])

    def test_colour_type_4_grey_alpha_replicates_to_rgb(self, tmp_path):
        p = tmp_path / "t.png"
        p.write_bytes(_build_png(2, 1, 4, 8, [bytes([50, 128, 200, 10])]))
        img = read_png(str(p))
        assert img.rgba == bytes([50, 50, 50, 128, 200, 200, 200, 10])

    def test_colour_type_6_rgba_passes_through(self, tmp_path):
        p = tmp_path / "t.png"
        p.write_bytes(_build_png(2, 1, 6, 8, [bytes([1, 2, 3, 4, 5, 6, 7, 8])]))
        img = read_png(str(p))
        assert img.rgba == bytes([1, 2, 3, 4, 5, 6, 7, 8])


class TestPalette:
    def test_indices_resolve_through_plte_not_returned_as_pixels(self, tmp_path):
        plte = bytes([255, 0, 0, 0, 255, 0])   # index 0 -> red, index 1 -> green
        p = tmp_path / "t.png"
        p.write_bytes(_build_png(2, 1, 3, 8, [bytes([0, 1])], plte=plte))
        img = read_png(str(p))
        assert img.rgba == bytes([255, 0, 0, 255, 0, 255, 0, 255])

    def test_trns_supplies_alpha_and_missing_entries_default_to_255(self, tmp_path):
        plte = bytes([255, 0, 0, 0, 255, 0])
        trns = bytes([128])   # only index 0 has an alpha entry
        p = tmp_path / "t.png"
        p.write_bytes(_build_png(2, 1, 3, 8, [bytes([0, 1])], plte=plte, trns=trns))
        img = read_png(str(p))
        assert img.rgba == bytes([255, 0, 0, 128, 0, 255, 0, 255])

    def test_palette_png_with_no_plte_raises(self, tmp_path):
        p = tmp_path / "t.png"
        p.write_bytes(_build_png(2, 1, 3, 8, [bytes([0, 1])]))
        with pytest.raises(UnsupportedPngError):
            read_png(str(p))


class TestFilterTypes:
    """PNG filter types 1-4 (Sub, Up, Average, Paeth). `_build_png` above only
    ever emits filter 0, same as `write_png` -- these fixtures are forward-
    filtered here instead, with a predictor implementation independent of
    `png._unfilter`, so a bug in one isn't masked by reuse of the other."""

    @staticmethod
    def _forward_filter(kind, rows, nch):
        prev = bytearray(len(rows[0]))
        filtered = []
        for row in rows:
            raw = bytearray(row)
            filt = bytearray(len(raw))
            for x in range(len(raw)):
                left = raw[x - nch] if x >= nch else 0
                up = prev[x]
                upleft = prev[x - nch] if x >= nch else 0
                if kind == 1:
                    pred = left
                elif kind == 2:
                    pred = up
                elif kind == 3:
                    pred = (left + up) // 2
                else:
                    p = left + up - upleft
                    pa, pb, pc = abs(p - left), abs(p - up), abs(p - upleft)
                    pred = left if (pa <= pb and pa <= pc) else (up if pb <= pc else upleft)
                filt[x] = (raw[x] - pred) & 0xFF
            filtered.append(bytes(filt))
            prev = raw
        return filtered

    def _build_filtered_png(self, width, height, colour, nch, rows, kind):
        scanlines = b"".join(bytes([kind]) + r
                              for r in self._forward_filter(kind, rows, nch))
        chunks = [_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, colour, 0, 0, 0)),
                  _chunk(b"IDAT", zlib.compress(scanlines, 6)),
                  _chunk(b"IEND", b"")]
        return PNG_MAGIC + b"".join(chunks)

    @pytest.mark.parametrize("kind", [1, 2, 3, 4])
    def test_filter_recovers_original_pixels(self, tmp_path, kind):
        # 2x2 RGBA (colour type 6, nch=4): two rows and two pixels per row
        # exercises left, up, and upleft predictor terms all at once, with
        # every byte distinct so a wrong predictor lands on a wrong byte at
        # a specific offset rather than coincidentally the right one.
        w, h = 2, 2
        rgba = bytes(range(4 * w * h))
        rows = [rgba[0:w * 4], rgba[w * 4:2 * w * 4]]
        p = tmp_path / "t.png"
        p.write_bytes(self._build_filtered_png(w, h, 6, 4, rows, kind))
        img = read_png(str(p))
        assert img.rgba == rgba


class TestRejectedSurface:
    def test_16bit_depth_raises_and_says_to_resave_as_8bit(self, tmp_path):
        p = tmp_path / "t.png"
        p.write_bytes(_build_png(2, 1, 2, 16, [bytes(12)]))
        with pytest.raises(UnsupportedPngError, match="8-bit"):
            read_png(str(p))

    def test_interlaced_png_raises(self, tmp_path):
        p = tmp_path / "t.png"
        p.write_bytes(_build_png(2, 1, 2, 8, [bytes([1, 2, 3, 4, 5, 6])], interlace=1))
        with pytest.raises(UnsupportedPngError):
            read_png(str(p))

    def test_non_png_file_raises(self, tmp_path):
        p = tmp_path / "t.png"
        p.write_bytes(b"not a png")
        with pytest.raises(ValueError):
            read_png(str(p))
