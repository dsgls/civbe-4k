"""DXT1/DXT2/DXT3/DXT4/DXT5 block decoding.

Expected RGBA values below are hand-computed from the formulas in
*Decoding* in the design spec, not derived by reading the implementation.
"""
import struct

import pytest

from civbe_dds.dxt import (
    decode, decode_dxt1_block, decode_dxt3_block, decode_dxt5_block,
)


def _dxt1_block(c0, c1, indices):
    """Pack a DXT1 block from raw 565 endpoints and 16 2-bit indices."""
    bits = 0
    for i, idx in enumerate(indices):
        bits |= idx << (2 * i)
    return struct.pack("<HHI", c0, c1, bits)


def _dxt3_block(nibbles, c0, c1, indices):
    """Pack a DXT3 block from 16 4-bit alpha nibbles and a colour half."""
    alpha = bytearray(8)
    for i, a in enumerate(nibbles):
        alpha[i >> 1] |= a << (4 * (i & 1))
    return bytes(alpha) + _dxt1_block(c0, c1, indices)[:8]


def _dxt5_block(a0, a1, alpha_indices, c0, c1, indices):
    """Pack a DXT5 block from the two alpha endpoints, 16 3-bit alpha
    indices, and a colour half."""
    bits = 0
    for i, idx in enumerate(alpha_indices):
        bits |= idx << (3 * i)
    alpha_half = bytes((a0, a1)) + bits.to_bytes(6, "little")
    return alpha_half + _dxt1_block(c0, c1, indices)[:8]


class TestDxt1:
    def test_opaque_four_colour_mode(self):
        # c0 = red (0xF800), c1 = black (0x0000); c0 > c1 selects 4-colour
        # opaque mode. Expanded 8-bit endpoints: (255,0,0) and (0,0,0).
        # color2 = (2*255+0+1)//3 = 170, color3 = (255+2*0+1)//3 = 85.
        block = _dxt1_block(0xF800, 0x0000,
                             [0, 1, 2, 3] + [0] * 12)
        texels = decode_dxt1_block(block)
        assert texels[0] == (255, 0, 0, 255)
        assert texels[1] == (0, 0, 0, 255)
        assert texels[2] == (170, 0, 0, 255)
        assert texels[3] == (85, 0, 0, 255)
        assert texels[4] == (255, 0, 0, 255)

    def test_punch_through_mode_is_not_a_corner_case(self):
        # c0 = black (0x0000), c1 = red (0xF800); c0 <= c1 selects 3-colour
        # punch-through mode. color2 = avg = (0+255+1)//2 = 128; index 3 is
        # transparent black.
        block = _dxt1_block(0x0000, 0xF800,
                             [0, 1, 2, 3] + [0] * 12)
        texels = decode_dxt1_block(block)
        assert texels[0] == (0, 0, 0, 255)
        assert texels[1] == (255, 0, 0, 255)
        assert texels[2] == (128, 0, 0, 255)
        assert texels[3] == (0, 0, 0, 0)

    def test_ffff_endpoint_expands_to_pure_white(self):
        # High-bit replication: r5=g6=b5=all-ones -> 255,255,255. A bare
        # left-shift would give (248, 252, 248) instead.
        block = _dxt1_block(0xFFFF, 0x0000, [0] * 16)
        texels = decode_dxt1_block(block)
        assert texels[0] == (255, 255, 255, 255)
        assert all(t == (255, 255, 255, 255) for t in texels)


class TestDxt3:
    def test_alpha_nibble_expansion(self):
        # nibble 15 -> 255 (15*17), not the 240 that `a << 4` would give.
        # nibble 0 -> 0.
        block = _dxt3_block([15, 0] + [0] * 14,
                             c0=0x0000, c1=0x0000, indices=[0] * 16)
        texels = decode_dxt3_block(block)
        assert texels[0] == (0, 0, 0, 255)
        assert texels[1] == (0, 0, 0, 0)

    def test_colour_half_is_always_four_colour_mode(self):
        # c0 < c1 here; DXT3's colour half still uses 4-colour interpolation
        # (unlike DXT1's punch-through), so index 3 is an interpolated
        # colour, not transparent black.
        block = _dxt3_block([15] * 16,
                             c0=0x0000, c1=0xF800, indices=[3] + [0] * 15)
        texels = decode_dxt3_block(block)
        # color3 = (r0+2*r1+1)//3 = (0+510+1)//3 = 170
        assert texels[0] == (170, 0, 0, 255)


class TestDxt5:
    def test_six_value_interpolation_mode(self):
        # a0=255 > a1=0 selects the 6-value / denominator-7 mode.
        # table[2] = (6*255 + 0)//7 = 218.
        block = _dxt5_block(a0=255, a1=0,
                             alpha_indices=[0, 1, 2] + [0] * 13,
                             c0=0x0000, c1=0x0000, indices=[0] * 16)
        texels = decode_dxt5_block(block)
        assert texels[0][3] == 255
        assert texels[1][3] == 0
        assert texels[2][3] == 218

    def test_four_value_interpolation_mode_and_literal_entries(self):
        # a0=0 <= a1=255 selects the 4-value / denominator-5 mode, with
        # literal table[6]=0 and table[7]=255 -- not derived from a0/a1.
        # table[2] = (1*255)//5 = 51.
        block = _dxt5_block(a0=0, a1=255,
                             alpha_indices=[6, 7, 2] + [0] * 13,
                             c0=0x0000, c1=0x0000, indices=[0] * 16)
        texels = decode_dxt5_block(block)
        assert texels[0][3] == 0     # literal table[6]
        assert texels[1][3] == 255   # literal table[7]
        assert texels[2][3] == 51


class TestDxt2Dxt4:
    def test_dxt2_decodes_identically_to_dxt3_with_no_alpha_division(self):
        block = _dxt3_block([15, 8] + [0] * 14,
                             c0=0xF800, c1=0x0000, indices=[1] + [0] * 15)
        dxt2 = decode(b"DXT2", block, 4, 4)
        assert dxt2 == decode(b"DXT3", block, 4, 4)
        # Real values, not just cross-decoder equality -- an alpha division
        # applied identically to both paths would still pass the equality
        # assertion above.
        assert tuple(dxt2[0:4]) == (0, 0, 0, 255)     # texel 0: colour index 1 -> c1 (black); nibble 15 -> alpha 255
        assert tuple(dxt2[4:8]) == (255, 0, 0, 136)   # texel 1: colour index 0 -> c0 (red); nibble 8 -> alpha 136

    def test_dxt4_decodes_identically_to_dxt5_with_no_alpha_division(self):
        block = _dxt5_block(a0=255, a1=0,
                             alpha_indices=[3] + [0] * 15,
                             c0=0xF800, c1=0x0000, indices=[1] + [0] * 15)
        dxt4 = decode(b"DXT4", block, 4, 4)
        assert dxt4 == decode(b"DXT5", block, 4, 4)
        # table[3] for a0=255 > a1=0 (six-value mode): i = 3-2 = 1,
        # ((6-1)*255 + (1+1)*0)//7 = 1275//7 = 182
        assert tuple(dxt4[0:4]) == (0, 0, 0, 182)     # texel 0: colour index 1 -> c1 (black); alpha index 3 -> table[3]
        assert tuple(dxt4[4:8]) == (255, 0, 0, 255)   # texel 1: colour index 0 -> c0 (red); alpha index 0 -> a0


class TestLiteralByteLayout:
    """Every fixture above is built by a helper that packs fields the same
    way the decoder unpacks them -- the algebraic inverse of the decoder, so
    it cannot catch a mirrored on-disk layout (a swapped nibble order, a
    misread index field) if the decoder and the helper share the same
    mistake. These fixtures are literal bytes instead."""

    def test_dxt1_index_field_low_bits_are_texel_0(self):
        # Index dword byte 0 = 0b00000001: texel 0 = bits 0-1 = 0b01 (index
        # 1, black); texel 1 = bits 2-3 = 0b00 (index 0, red). c0 = red,
        # c1 = black, c0 > c1 selects 4-colour opaque mode.
        block = struct.pack("<HH", 0xF800, 0x0000) + bytes([0b00000001, 0, 0, 0])
        texels = decode_dxt1_block(block)
        assert texels[0] == (0, 0, 0, 255)
        assert texels[1] == (255, 0, 0, 255)
        assert texels[2] == (255, 0, 0, 255)

    def test_dxt3_alpha_nibble_order_is_low_nibble_first(self):
        # Byte 0 = 0xF0: low nibble (texel 0) = 0x0 -> alpha 0; high nibble
        # (texel 1) = 0xF -> alpha 255. A mirrored nibble order swaps these
        # two assertions.
        alpha = b"\xf0" + b"\x00" * 7
        colour = b"\x00" * 8   # c0 = c1 = 0, index 0 -> rgb (0,0,0) everywhere
        texels = decode_dxt3_block(alpha + colour)
        assert texels[0] == (0, 0, 0, 0)
        assert texels[1] == (0, 0, 0, 255)

    def test_dxt5_alpha_index_field_is_48bit_little_endian(self):
        # a0=255, a1=0 selects the six-value table:
        # [255, 0, 218, 182, 145, 109, 72, 36]. Index bytes [0x00, 0x80, 0,
        # 0, 0, 0] set only bit 15 -- the top bit of the second index byte
        # (block byte 3) -- which lands in texel 5's 3-bit field (bits
        # 15-17), crossing the byte-2/byte-3 boundary. A field read with the
        # wrong byte order or width would place this bit in a different
        # texel.
        alpha = bytes([255, 0]) + bytes([0x00, 0x80, 0x00, 0x00, 0x00, 0x00])
        colour = b"\x00" * 8
        texels = decode_dxt5_block(alpha + colour)
        assert texels[4][3] == 255   # table[0] = a0, unaffected
        assert texels[5][3] == 0     # table[1] = a1
        assert texels[6][3] == 255   # table[0] = a0, unaffected


class TestDecodeSurface:
    def test_dimensions_not_a_multiple_of_four_are_cropped(self):
        # The top-left block's colour varies by row (not solid), so a
        # texel -> (row, col) transposition inside a block would be visible:
        # every pixel in a row must match, and colour must change moving
        # down a column but not across it.
        red, black = 0xF800, 0x0000
        top_left = _dxt1_block(red, black, [t // 4 for t in range(16)])
        # c0 = red (255,0,0), c1 = black (0,0,0), c0 > c1 -> 4-colour opaque:
        # row 0 = index 0 = red, row 1 = index 1 = black,
        # row 2 = index 2 = (2*255+0+1)//3 = 170, row 3 = index 3 = 85.
        green, blue, white = 0x07E0, 0x001F, 0xFFFF
        data = top_left + b"".join(
            _dxt1_block(c, c, [0] * 16) for c in (green, blue, white)
        )
        rgba = decode(b"DXT1", data, 5, 5)
        assert len(rgba) == 5 * 5 * 4

        def px(x, y):
            o = (y * 5 + x) * 4
            return tuple(rgba[o:o + 4])

        assert px(0, 0) == (255, 0, 0, 255)      # row 0
        assert px(3, 0) == (255, 0, 0, 255)      # same row as (0,0): must match
        assert px(0, 1) == (0, 0, 0, 255)        # row 1
        assert px(0, 3) == (85, 0, 0, 255)       # row 3
        assert px(3, 3) == (85, 0, 0, 255)       # same row as (0,3): must match
        assert px(4, 0) == (0, 255, 0, 255)      # top-right block: green
        assert px(0, 4) == (0, 0, 255, 255)      # bottom-left block: blue
        assert px(4, 4) == (255, 255, 255, 255)  # bottom-right block: white

    def test_unrecognized_fourcc_raises(self):
        with pytest.raises(ValueError):
            decode(b"DXT9", b"\0" * 8, 4, 4)
