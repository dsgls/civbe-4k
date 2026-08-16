"""DXT1/DXT2/DXT3/DXT4/DXT5 block decoding to RGBA.

See *Decoding* in the design spec for the block and texel layout and every
formula here -- the endpoint expansion, the DXT1 mode split, and the DXT5
alpha table are copied from there verbatim, not from a general BCn
description. Each one differs from the "obvious" formula in a way that
measurably damaged this project's art when gotten wrong.
"""
import struct

BLOCK_BYTES = {b"DXT1": 8, b"DXT2": 16, b"DXT3": 16, b"DXT4": 16, b"DXT5": 16}


def _expand565(c):
    """RGB565 -> 8-bit-per-channel RGB by high-bit replication:
    (v<<3)|(v>>2) for a 5-bit channel, (v<<2)|(v>>4) for 6-bit. 0xFFFF must
    give (255,255,255); a bare left-shift gives (248,252,248) and darkens
    every DXT texel in the project by ~3%.
    """
    r5, g6, b5 = (c >> 11) & 0x1F, (c >> 5) & 0x3F, c & 0x1F
    return (r5 << 3) | (r5 >> 2), (g6 << 2) | (g6 >> 4), (b5 << 3) | (b5 >> 2)


def _dxt1_palette(c0, c1):
    """Four RGBA colours for a DXT1 block. c0 > c1 is 4-colour opaque mode;
    otherwise 3 colours plus transparent black at index 3 -- the majority
    path in this project's art (forgeui_scrollbar is 220 of 256 blocks), not
    a corner case.
    """
    r0, g0, b0 = _expand565(c0)
    r1, g1, b1 = _expand565(c1)
    if c0 > c1:
        c2 = ((2 * r0 + r1 + 1) // 3, (2 * g0 + g1 + 1) // 3, (2 * b0 + b1 + 1) // 3)
        c3 = ((r0 + 2 * r1 + 1) // 3, (g0 + 2 * g1 + 1) // 3, (b0 + 2 * b1 + 1) // 3)
        return [(r0, g0, b0, 255), (r1, g1, b1, 255), c2 + (255,), c3 + (255,)]
    c2 = ((r0 + r1 + 1) // 2, (g0 + g1 + 1) // 2, (b0 + b1 + 1) // 2)
    return [(r0, g0, b0, 255), (r1, g1, b1, 255), c2 + (255,), (0, 0, 0, 0)]


def decode_dxt1_block(block):
    """8-byte DXT1 block -> 16 RGBA texels, row-major left to right then top
    to bottom. Indices are a 32-bit little-endian field, texel 0 in the low
    2 bits."""
    c0, c1 = struct.unpack_from("<HH", block, 0)
    indices, = struct.unpack_from("<I", block, 4)
    palette = _dxt1_palette(c0, c1)
    return [palette[(indices >> (2 * i)) & 0x3] for i in range(16)]


def _bc_rgb_texels(block, offset):
    """16 RGB texels from the 8-byte colour half of a DXT3/DXT5 block at
    `offset`. Always 4-colour interpolation, whatever c0 and c1 compare as --
    unlike DXT1, this half never has a punch-through/transparent mode.
    Alpha comes from the separate alpha half, not from index 3.
    """
    c0, c1 = struct.unpack_from("<HH", block, offset)
    indices, = struct.unpack_from("<I", block, offset + 4)
    r0, g0, b0 = _expand565(c0)
    r1, g1, b1 = _expand565(c1)
    palette = [
        (r0, g0, b0), (r1, g1, b1),
        ((2 * r0 + r1 + 1) // 3, (2 * g0 + g1 + 1) // 3, (2 * b0 + b1 + 1) // 3),
        ((r0 + 2 * r1 + 1) // 3, (g0 + 2 * g1 + 1) // 3, (b0 + 2 * b1 + 1) // 3),
    ]
    return [palette[(indices >> (2 * i)) & 0x3] for i in range(16)]


def decode_dxt3_block(block):
    """16-byte DXT3 block -> 16 RGBA texels. Alpha is 4 bits per texel, texel
    i in nibble i of the first 8 bytes (low nibble of byte 0 first) --
    `(alpha[i>>1] >> (4*(i&1))) & 0xf` -- expanded to 8 bits by replication,
    a * 17. `a << 4` would leave an opaque texel at 240, not 255.
    """
    alpha = block[0:8]
    rgb = _bc_rgb_texels(block, 8)
    return [rgb[i] + (((alpha[i >> 1] >> (4 * (i & 1))) & 0xF) * 17,)
            for i in range(16)]


def _dxt5_alpha_table(a0, a1):
    """8-entry alpha table for a DXT5 block. a0 > a1 interpolates 6 values
    over denominator 7; otherwise 4 values over denominator 5 plus the two
    literal entries 0 and 255 at indices 6 and 7. The second mode is not the
    rare one: 29.8% of stock DXT4 blocks use it, forgeui_glass entirely so,
    and applying the 6-value formula to it puts wrong alpha on 42% of
    forgeui_pulldown_corner.
    """
    table = [a0, a1, 0, 0, 0, 0, 0, 0]
    if a0 > a1:
        for i in range(6):
            table[2 + i] = ((6 - i) * a0 + (1 + i) * a1) // 7
    else:
        for i in range(4):
            table[2 + i] = ((4 - i) * a0 + (1 + i) * a1) // 5
        table[6], table[7] = 0, 255
    return table


def decode_dxt5_block(block):
    """16-byte DXT5 block -> 16 RGBA texels. Alpha indices are a 48-bit
    little-endian field in bytes 2..7, texel 0 in the low 3 bits."""
    a0, a1 = block[0], block[1]
    table = _dxt5_alpha_table(a0, a1)
    indices = int.from_bytes(block[2:8], "little")
    rgb = _bc_rgb_texels(block, 8)
    return [rgb[i] + (table[(indices >> (3 * i)) & 0x7],) for i in range(16)]


# DXT2/DXT4 claim premultiplied alpha; the data on disk is not premultiplied,
# so decoding them exactly as DXT3/DXT5 -- and never dividing out alpha --
# is correct, not a shortcut.
_BLOCK_DECODERS = {
    b"DXT1": decode_dxt1_block,
    b"DXT2": decode_dxt3_block,
    b"DXT3": decode_dxt3_block,
    b"DXT4": decode_dxt5_block,
    b"DXT5": decode_dxt5_block,
}


def decode(fourcc, data, width, height):
    """Decode tightly-packed block data for `fourcc` to RGBA bytes, width *
    height * 4 long.

    Blocks are laid out row-major, left to right then top to bottom, as are
    the texels within each block. The image is decoded on a 4x4 grid and
    cropped to (width, height).
    """
    try:
        block_fn = _BLOCK_DECODERS[fourcc]
    except KeyError:
        raise ValueError("not a DXT fourCC: %r" % fourcc)
    block_size = BLOCK_BYTES[fourcc]

    blocks_wide, blocks_high = -(-width // 4), -(-height // 4)
    padded_w, padded_h = blocks_wide * 4, blocks_high * 4
    buf = bytearray(padded_w * padded_h * 4)

    pos = 0
    for by in range(blocks_high):
        for bx in range(blocks_wide):
            texels = block_fn(data[pos:pos + block_size])
            pos += block_size
            for t, (r, g, b, a) in enumerate(texels):
                row, col = t // 4, t % 4
                o = ((by * 4 + row) * padded_w + bx * 4 + col) * 4
                buf[o:o + 4] = bytes((r, g, b, a))

    if (padded_w, padded_h) == (width, height):
        return bytes(buf)
    out = bytearray(width * height * 4)
    for y in range(height):
        src = y * padded_w * 4
        out[y * width * 4:(y + 1) * width * 4] = buf[src:src + width * 4]
    return bytes(out)
