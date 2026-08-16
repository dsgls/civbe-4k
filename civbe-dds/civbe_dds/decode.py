"""Format dispatcher: any supported .dds -> its level-0 Image.

Resolves a dictionary-pair sibling itself, so callers never branch on
pair-vs-plain. Mip levels past 0, cubemap faces past 0, and L16's low byte
are dropped by design -- see *Decoding* in the design spec.
"""
import struct
import sys

from . import dxt, pair
from .header import (
    DDPF_FOURCC, DDPF_LUMINANCE, DDSCAPS2_CUBEMAP, HEADER_LEN, channel_order,
    header,
)
from .image import Image

_FIC_FOURCC = struct.pack("<I", 114)   # D3DFMT#114, the .fic stub format


class UnsupportedFormatError(ValueError):
    """A recognised but unhandled pixel format, e.g. the .fic fourCC."""


def read(path):
    """Decode any supported .dds to an Image holding its level-0 pixels.

    A dictionary-pair file (one with a `-index.dds` sibling) decodes through
    `pair.decode_pair`; everything else decodes as a single plain texture.
    A cubemap decodes face 0, which starts at the same offset as any other
    texture, and warns on stderr about the dropped faces.
    """
    if pair.is_pair(path):
        return pair.decode_pair(path)

    hdr = header(path)
    if hdr is None:
        raise ValueError("not a DDS: %s" % path)

    if hdr.caps2 & DDSCAPS2_CUBEMAP:
        print("%s: cubemap, decoding face 0 only" % path, file=sys.stderr)

    if hdr.pfflags & DDPF_FOURCC:
        if hdr.fourcc in dxt.BLOCK_BYTES:
            return _read_dxt(path, hdr)
        if hdr.fourcc == _FIC_FOURCC:
            raise UnsupportedFormatError(
                "%s: .fic textures (D3DFMT#114) are not supported" % path)
        raise UnsupportedFormatError(
            "unsupported fourCC %r: %s" % (hdr.fourcc, path))

    if hdr.pfflags & DDPF_LUMINANCE:
        return _read_luminance(path, hdr)

    if hdr.bits == 32:
        return _read_32bit(path, hdr)

    raise UnsupportedFormatError("unsupported pixel format: %s" % path)


def _read_32bit(path, hdr):
    """A8B8G8R8 or A8R8G8B8, whichever the header's R mask names.

    `channel_order` raises rather than guessing when the mask matches
    neither shipped order; that propagates out of `read` unchanged.
    """
    order = channel_order(hdr)
    with open(path, "rb") as fh:
        fh.seek(HEADER_LEN)
        data = fh.read(hdr.width * hdr.height * 4)
    if order == (0, 1, 2, 3):
        rgba = data
    else:
        # order == (2, 1, 0, 3): bytes on disk are B,G,R,A -- swap the R and
        # B slots to get R,G,B,A.
        out = bytearray(data)
        out[0::4], out[2::4] = bytes(out[2::4]), bytes(out[0::4])
        rgba = bytes(out)
    return Image(width=hdr.width, height=hdr.height, rgba=rgba, group=hdr.group)


def _read_luminance(path, hdr):
    """L8 or L16, replicated to R=G=B with opaque alpha.

    L16 keeps only the high byte of each little-endian sample -- lossy and
    deliberate, see *Decoding* in the design spec.
    """
    if hdr.bits not in (8, 16):
        raise UnsupportedFormatError(
            "unsupported luminance depth %d: %s" % (hdr.bits, path))
    n = hdr.width * hdr.height
    with open(path, "rb") as fh:
        fh.seek(HEADER_LEN)
        data = fh.read(n * (hdr.bits // 8))
    grey = data if hdr.bits == 8 else data[1::2]
    out = bytearray(n * 4)
    for i in range(n):
        v = grey[i]
        out[4 * i:4 * i + 3] = bytes((v, v, v))
        out[4 * i + 3] = 255
    return Image(width=hdr.width, height=hdr.height, rgba=bytes(out), group=hdr.group)


def _read_dxt(path, hdr):
    """Any DXT1-5 fourCC, delegating the block math to `dxt.decode`.

    Reads the padded 4x4-grid byte count, not width*height*4/bytes-per-texel
    -- a non-multiple-of-4 image still occupies whole blocks on disk.
    """
    blocks_wide, blocks_high = -(-hdr.width // 4), -(-hdr.height // 4)
    nbytes = blocks_wide * blocks_high * dxt.BLOCK_BYTES[hdr.fourcc]
    with open(path, "rb") as fh:
        fh.seek(HEADER_LEN)
        data = fh.read(nbytes)
    rgba = dxt.decode(hdr.fourcc, data, hdr.width, hdr.height)
    return Image(width=hdr.width, height=hdr.height, rgba=rgba, group=hdr.group)
