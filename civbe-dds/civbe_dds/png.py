"""PNG reader and writer, ported from `analysis/dds.py` and extended.

`write_png` always emits 8-bit RGBA (colour type 6). `read_png` accepts the
surface a real upscaler emits and always returns RGBA -- unlike the original,
which handed back raw scanlines and a channel count, indistinguishable from
pixel data for a palette image.
"""
import struct
import zlib

from .image import Image

PNG_MAGIC = b"\x89PNG\r\n\x1a\n"

_CHANNELS_BY_COLOUR_TYPE = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


class UnsupportedPngError(ValueError):
    """A PNG outside the accepted surface: interlaced, non-8-bit depth, or an
    unhandled colour type."""


def write_png(path, image):
    """Write `image` as an 8-bit, non-interlaced RGBA PNG."""
    w, h, rgba = image.width, image.height, image.rgba

    def chunk(kind, payload):
        body = kind + payload
        return struct.pack(">I", len(payload)) + body + \
            struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    scanlines = b"".join(b"\0" + rgba[y * w * 4:(y + 1) * w * 4]
                          for y in range(h))
    with open(path, "wb") as fh:
        fh.write(PNG_MAGIC
                  + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                  + chunk(b"IDAT", zlib.compress(scanlines, 6))
                  + chunk(b"IEND", b""))


def read_png(path):
    """Read a PNG into an RGBA Image.

    Accepts 8-bit, non-interlaced colour types 0, 2, 3, 4 and 6. Type 3
    (palette) is resolved through PLTE, with tRNS supplying alpha where
    present and 255 elsewhere -- returning raw indices as pixels would be
    silently-plausible garbage. 16-bit depth raises UnsupportedPngError with
    a message telling the caller to re-save as 8-bit, since ESRGAN-family
    upscalers emit 16-bit PNGs routinely.
    """
    with open(path, "rb") as fh:
        d = fh.read()
    if d[:8] != PNG_MAGIC:
        raise ValueError("not a PNG: %s" % path)

    pos, idat = 8, []
    palette = trns = None
    w = h = colour = None
    while pos < len(d):
        n, = struct.unpack_from(">I", d, pos)
        kind, payload = d[pos + 4:pos + 8], d[pos + 8:pos + 8 + n]
        pos += 12 + n
        if kind == b"IHDR":
            w, h, depth, colour, _, _, interlace = struct.unpack(">IIBBBBB", payload)
            if depth == 16:
                raise UnsupportedPngError(
                    "%s is a 16-bit PNG; re-save as 8-bit" % path)
            if depth != 8:
                raise UnsupportedPngError(
                    "unsupported PNG bit depth %d: %s" % (depth, path))
            if interlace:
                raise UnsupportedPngError("interlaced PNG not supported: %s" % path)
            if colour not in _CHANNELS_BY_COLOUR_TYPE:
                raise UnsupportedPngError(
                    "unsupported PNG colour type %d: %s" % (colour, path))
        elif kind == b"PLTE":
            palette = payload
        elif kind == b"tRNS":
            trns = payload
        elif kind == b"IDAT":
            idat.append(payload)
        elif kind == b"IEND":
            break

    nch = _CHANNELS_BY_COLOUR_TYPE[colour]
    raw = zlib.decompress(b"".join(idat))
    scan = _unfilter(raw, w, h, nch)
    rgba = _expand_rgba(scan, w, h, colour, palette, trns)
    return Image(width=w, height=h, rgba=rgba, group="")


def _expand_rgba(scan, w, h, colour, palette, trns):
    n = w * h
    if colour == 6:
        return bytes(scan)

    out = bytearray(n * 4)
    if colour == 2:
        for i in range(n):
            out[4 * i:4 * i + 3] = scan[3 * i:3 * i + 3]
            out[4 * i + 3] = 255
    elif colour == 0:
        for i in range(n):
            v = scan[i]
            out[4 * i:4 * i + 3] = bytes((v, v, v))
            out[4 * i + 3] = 255
    elif colour == 4:
        for i in range(n):
            v, a = scan[2 * i], scan[2 * i + 1]
            out[4 * i:4 * i + 3] = bytes((v, v, v))
            out[4 * i + 3] = a
    elif colour == 3:
        if palette is None:
            raise UnsupportedPngError("palette PNG has no PLTE chunk")
        for i in range(n):
            idx = scan[i]
            out[4 * i:4 * i + 3] = palette[3 * idx:3 * idx + 3]
            out[4 * i + 3] = trns[idx] if trns is not None and idx < len(trns) else 255
    return bytes(out)


def _unfilter(raw, width, height, nch):
    stride = width * nch
    out = bytearray(stride * height)
    prev = bytearray(stride)
    pos = 0
    for y in range(height):
        kind = raw[pos]; pos += 1
        line = bytearray(raw[pos:pos + stride]); pos += stride
        if kind == 1:
            for x in range(nch, stride):
                line[x] = (line[x] + line[x - nch]) & 0xFF
        elif kind == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 0xFF
        elif kind == 3:
            for x in range(stride):
                left = line[x - nch] if x >= nch else 0
                line[x] = (line[x] + ((left + prev[x]) >> 1)) & 0xFF
        elif kind == 4:
            for x in range(stride):
                left = line[x - nch] if x >= nch else 0
                up = prev[x]
                upleft = prev[x - nch] if x >= nch else 0
                pa, pb, pc = abs(up - upleft), abs(left - upleft), \
                    abs(left + up - 2 * upleft)
                pred = left if (pa <= pb and pa <= pc) else (up if pb <= pc else upleft)
                line[x] = (line[x] + pred) & 0xFF
        elif kind != 0:
            raise ValueError("bad PNG filter %d" % kind)
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return bytes(out)
