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
        assert decode(b"DXT2", block, 4, 4) == decode(b"DXT3", block, 4, 4)

    def test_dxt4_decodes_identically_to_dxt5_with_no_alpha_division(self):
        block = _dxt5_block(a0=255, a1=0,
                             alpha_indices=[3] + [0] * 15,
                             c0=0xF800, c1=0x0000, indices=[1] + [0] * 15)
        assert decode(b"DXT4", block, 4, 4) == decode(b"DXT5", block, 4, 4)


class TestDecodeSurface:
    def test_dimensions_not_a_multiple_of_four_are_cropped(self):
        # Four distinct solid-colour DXT1 blocks laid out 2x2, decoded at
        # 5x5 (padded internally to 8x8) so the crop must discard the right
        # rows/columns, not just truncate the byte count.
        red, green, blue, white = 0xF800, 0x07E0, 0x001F, 0xFFFF
        data = b"".join(
            _dxt1_block(c, c, [0] * 16) for c in (red, green, blue, white)
        )
        rgba = decode(b"DXT1", data, 5, 5)
        assert len(rgba) == 5 * 5 * 4

        def px(x, y):
            o = (y * 5 + x) * 4
            return tuple(rgba[o:o + 4])

        assert px(0, 0) == (255, 0, 0, 255)      # top-left block: red
        assert px(3, 3) == (255, 0, 0, 255)      # still inside top-left block
        assert px(4, 0) == (0, 255, 0, 255)      # top-right block: green
        assert px(0, 4) == (0, 0, 255, 255)      # bottom-left block: blue
        assert px(4, 4) == (255, 255, 255, 255)  # bottom-right block: white

    def test_unrecognized_fourcc_raises(self):
        with pytest.raises(ValueError):
            decode(b"DXT9", b"\0" * 8, 4, 4)
