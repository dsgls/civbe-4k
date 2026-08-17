"""Dictionary/index pair decode -- tile-deduplicated textures.

See *Dictionary pairs* in the top-level README for the format. The dictionary
holds each distinct NxN tile once, packed row-major into a rectangle; the
index holds one tile number per tile of the output. Decoding is a verbatim
copy of the referenced tile for every index texel, so it is lossless.
"""
import os
import struct

from .header import HEADER_LEN, channel_order, header
from .image import Image


class NotDictionaryCodedError(ValueError):
    """The dictionary file's FTXT tag is not a `BC0nn` tile size."""


def index_path(dds_path):
    return dds_path[:-len(".dds")] + "-index.dds"


def is_pair(dds_path):
    """True if `dds_path` has a `-index.dds` sibling -- i.e. is itself the
    dictionary half of a pair, not the index half or a plain texture."""
    return dds_path.endswith(".dds") and not dds_path.endswith("-index.dds") \
        and os.path.exists(index_path(dds_path))


def decode_pair(dds_path):
    """Decode a dictionary/index pair into an Image.

    N comes from the dictionary's `BC0nn` tag, hexadecimal -- `BC010` is 16
    and `BC020` is 32; every stock N is a power of two. Every stock
    dictionary's dimensions are exact multiples of N. `group` comes from the
    dictionary's FTXT block, not the index's.
    """
    dic = header(dds_path)
    idx = header(index_path(dds_path))
    if not dic or not idx:
        raise ValueError("not a DDS: %s" % dds_path)
    if not dic.tag.startswith("BC"):
        raise NotDictionaryCodedError(
            "%s is not dictionary-coded (tag %r)" % (dds_path, dic.tag))
    n = int(dic.tag[2:], 16)

    with open(dds_path, "rb") as fh:
        pal = fh.read()[HEADER_LEN:]
    with open(index_path(dds_path), "rb") as fh:
        raw = fh.read()[HEADER_LEN:]

    iw, ih = idx.width, idx.height
    if idx.bits == 8:
        keys = raw[:iw * ih]
    else:
        keys = struct.unpack("<%dH" % (iw * ih), raw[:iw * ih * 2])

    pw = dic.width
    cols = pw // n                       # tile slots per dictionary row
    w, h = iw * n, ih * n
    out = bytearray(w * h * 4)
    for by in range(ih):
        for bx in range(iw):
            k = keys[by * iw + bx]
            sx, sy = (k % cols) * n, (k // cols) * n
            for row in range(n):
                src = ((sy + row) * pw + sx) * 4
                dst = ((by * n + row) * w + bx * n) * 4
                out[dst:dst + n * 4] = pal[src:src + n * 4]

    order = channel_order(dic)
    if order != (0, 1, 2, 3):
        out[0::4], out[2::4] = bytes(out[2::4]), bytes(out[0::4])
    return Image(width=w, height=h, rgba=bytes(out), group=dic.group)
