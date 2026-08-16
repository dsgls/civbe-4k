#!/usr/bin/env python3
"""Reading the shipped DDS textures, and PNG just far enough to round-trip.

Stdlib only, so it runs anywhere the rest of the analysis does. See *The
texture format* in the top-level README for the format itself; this module is
the executable version of that description.
"""
import os, struct, zlib

DDS_MAGIC = b"DDS "
HEADER_LEN = 128          # 4-byte magic + 124-byte DDS_HEADER; pixels follow
DDPF_FOURCC = 0x4
DDPF_LUMINANCE = 0x20000


def header(path):
    """Parse a DDS header, including the two Firaxis fields in reserved space.

    `group` is the FTXT usage name and `tag` the format tag, both "" when
    absent. Junk trails the name in 21 forgeui_* files, hence the NUL split.
    """
    with open(path, "rb") as fh:
        d = fh.read(HEADER_LEN)
    if len(d) < HEADER_LEN or d[:4] != DDS_MAGIC:
        return None
    h, w = struct.unpack_from("<II", d, 12)
    mips, = struct.unpack_from("<I", d, 28)
    pfflags, = struct.unpack_from("<I", d, 80)
    bits, = struct.unpack_from("<I", d, 88)
    rmask, = struct.unpack_from("<I", d, 92)
    caps2, = struct.unpack_from("<I", d, 112)
    ftxt = d[32:36] == b"FTXT"
    return dict(
        width=w, height=h, mips=mips, pfflags=pfflags, fourcc=d[84:88],
        bits=bits, rmask=rmask, caps2=caps2,
        group=d[36:76].split(b"\0")[0].decode("latin1") if ftxt else "",
        tag=d[116:124].split(b"\0")[0].decode("latin1") if ftxt else "",
    )


def pixel_format(hdr):
    """A short name for the pixel format: 'DXT4', 'A8B8G8R8', 'L8', ..."""
    if hdr["pfflags"] & DDPF_FOURCC:
        fc = hdr["fourcc"]
        return "D3DFMT#%d" % fc[0] if fc[1:] == b"\0\0\0" else fc.decode("latin1")
    if hdr["pfflags"] & DDPF_LUMINANCE:
        return "L%d" % hdr["bits"]
    if hdr["bits"] == 32:
        # Both orders ship and the masks are honest; see the README.
        return {0xFF: "A8B8G8R8", 0xFF0000: "A8R8G8B8"}.get(hdr["rmask"], "?")
    return "?"


def channel_order(hdr):
    """Byte order of a 32-bit texture as an (r, g, b, a) index tuple."""
    return (0, 1, 2, 3) if hdr["rmask"] == 0xFF else (2, 1, 0, 3)


def index_path(dds_path):
    return dds_path[:-len(".dds")] + "-index.dds"


def is_pair(dds_path):
    return dds_path.endswith(".dds") and not dds_path.endswith("-index.dds") \
        and os.path.exists(index_path(dds_path))


def decode_pair(dds_path):
    """Decode a dictionary/index pair to (width, height, RGBA bytes).

    The dictionary holds each distinct NxN tile once, packed row-major into a
    rectangle; the index holds one tile number per tile of the output. N comes
    from the `BC0nn` tag and is decimal, so BC010 is 10 and not 16. Every
    output pixel is a verbatim copy, so this is lossless.

    The returned bytes are R,G,B,A regardless of the dictionary's mask order.
    """
    dic = header(dds_path)
    idx = header(index_path(dds_path))
    if not dic or not idx:
        raise ValueError("not a DDS: %s" % dds_path)
    if not dic["tag"].startswith("BC"):
        raise ValueError("%s is not dictionary-coded (tag %r)" % (dds_path, dic["tag"]))
    n = int(dic["tag"][2:])

    with open(dds_path, "rb") as fh:
        pal = fh.read()[HEADER_LEN:]
    with open(index_path(dds_path), "rb") as fh:
        raw = fh.read()[HEADER_LEN:]

    iw, ih = idx["width"], idx["height"]
    if idx["bits"] == 8:
        keys = raw[:iw * ih]
    else:
        keys = struct.unpack("<%dH" % (iw * ih), raw[:iw * ih * 2])

    pw = dic["width"]
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
    return w, h, bytes(out)


def write_png(path, width, height, rgba):
    def chunk(kind, payload):
        body = kind + payload
        return struct.pack(">I", len(payload)) + body + \
            struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    scanlines = b"".join(b"\0" + rgba[y * width * 4:(y + 1) * width * 4]
                         for y in range(height))
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n"
                 + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
                 + chunk(b"IDAT", zlib.compress(scanlines, 6))
                 + chunk(b"IEND", b""))


def read_png(path):
    """Read an 8-bit non-interlaced PNG as (width, height, channels, bytes)."""
    with open(path, "rb") as fh:
        d = fh.read()
    if d[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG: %s" % path)
    pos, idat, w = 8, [], None
    while pos < len(d):
        n, = struct.unpack_from(">I", d, pos)
        kind, payload = d[pos + 4:pos + 8], d[pos + 8:pos + 8 + n]
        pos += 12 + n
        if kind == b"IHDR":
            w, h, depth, colour, _, _, interlace = struct.unpack(">IIBBBBB", payload)
            if depth != 8 or interlace:
                raise ValueError("unsupported PNG in %s" % path)
        elif kind == b"IDAT":
            idat.append(payload)
        elif kind == b"IEND":
            break
    nch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[colour]
    raw = zlib.decompress(b"".join(idat))
    return w, h, nch, _unfilter(raw, w, h, nch)


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
