"""DDS header parsing and building, including the Firaxis FTXT fields.

See *The texture format* in the top-level README for the format itself; this
module is the executable version of that description. Ported from
`analysis/dds.py`, with the header as a dataclass instead of a dict.
"""
import struct
from dataclasses import dataclass

DDS_MAGIC = b"DDS "
HEADER_LEN = 128          # 4-byte magic + 124-byte DDS_HEADER; pixels follow

DDPF_ALPHAPIXELS = 0x1
DDPF_FOURCC = 0x4
DDPF_RGB = 0x40
DDPF_LUMINANCE = 0x20000

DDSCAPS_TEXTURE = 0x1000
DDSCAPS_COMPLEX = 0x8
DDSCAPS_MIPMAP = 0x400000
DDSCAPS2_CUBEMAP = 0x200

# dwFlags = DDSD_CAPS | DDSD_HEIGHT | DDSD_WIDTH | DDSD_PIXELFORMAT
#         | DDSD_MIPMAPCOUNT -- no DDSD_PITCH. dwPitchOrLinearSize is left 0
# and dwCaps carries DDSCAPS_COMPLEX | DDSCAPS_MIPMAP alongside
# DDSCAPS_TEXTURE, even though there is exactly one level: this is the
# combination all 756 stock plain single-level UI textures use, and the
# engine treats a conforming DDSD_PITCH/DDSCAPS_TEXTURE-only file as a
# distinct, non-default case. Matching stock, not the DDS documentation, is
# the goal here -- see *Encoding* in the design spec.
_HEADER_FLAGS = 0x21007

_FTXT_MAGIC = b"FTXT"
_USAGE_NAME_LEN = 40
_TAG_LEN = 8
_DEFAULT_GROUP = "Interface"
_ENCODE_TAG = "COLOR"


class UnrecognizedPixelFormatError(ValueError):
    """A 32-bit texture whose R mask matches neither shipped channel order."""


@dataclass
class DdsHeader:
    width: int
    height: int
    mips: int
    pfflags: int
    fourcc: bytes
    bits: int
    rmask: int
    caps2: int
    group: str    # FTXT usage name, "" when the file has no FTXT block
    tag: str      # FTXT format tag, "" when the file has no FTXT block


def header(path):
    """Parse a DDS header, including the two Firaxis fields in reserved space.

    Returns None if `path` is not a DDS file. `group` and `tag` are "" when
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
    ftxt = d[32:36] == _FTXT_MAGIC
    return DdsHeader(
        width=w, height=h, mips=mips, pfflags=pfflags, fourcc=d[84:88],
        bits=bits, rmask=rmask, caps2=caps2,
        group=d[36:76].split(b"\0")[0].decode("latin1") if ftxt else "",
        tag=d[116:124].split(b"\0")[0].decode("latin1") if ftxt else "",
    )


def build_header(width, height, group=None):
    """Build a 128-byte header for a plain, single-level A8B8G8R8 texture.

    This is the only pixel format civbe_dds writes -- see *Encoding* in the
    design spec. `group` falls back to "Interface", matching `write()`.
    """
    group = group or _DEFAULT_GROUP
    d = bytearray(HEADER_LEN)
    d[0:4] = DDS_MAGIC
    struct.pack_into("<I", d, 4, 124)                      # dwSize
    struct.pack_into("<I", d, 8, _HEADER_FLAGS)             # dwFlags
    struct.pack_into("<II", d, 12, height, width)
    struct.pack_into("<I", d, 24, 1)                        # dwDepth
    struct.pack_into("<I", d, 28, 1)                        # dwMipMapCount
    d[32:36] = _FTXT_MAGIC
    d[36:76] = group.encode("latin1")[:_USAGE_NAME_LEN].ljust(_USAGE_NAME_LEN, b"\0")
    struct.pack_into("<I", d, 76, 32)                       # pixelformat.dwSize
    struct.pack_into("<I", d, 80, DDPF_RGB | DDPF_ALPHAPIXELS)
    struct.pack_into("<I", d, 88, 32)                       # dwRGBBitCount
    struct.pack_into("<IIII", d, 92, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000)
    struct.pack_into("<I", d, 108,
                      DDSCAPS_TEXTURE | DDSCAPS_COMPLEX | DDSCAPS_MIPMAP)  # dwCaps
    d[116:124] = _ENCODE_TAG.encode("latin1")[:_TAG_LEN].ljust(_TAG_LEN, b"\0")
    return bytes(d)


def pixel_format(hdr):
    """A short display name for the pixel format: 'DXT4', 'A8B8G8R8', 'L8', ...

    Purely descriptive -- used by `info`, never to decide how to decode. An
    unrecognised 32-bit mask yields "?" here; `channel_order` is the one that
    must refuse to guess.
    """
    if hdr.pfflags & DDPF_FOURCC:
        fc = hdr.fourcc
        return "D3DFMT#%d" % fc[0] if fc[1:] == b"\0\0\0" else fc.decode("latin1")
    if hdr.pfflags & DDPF_LUMINANCE:
        return "L%d" % hdr.bits
    if hdr.bits == 32:
        # Both orders ship and the masks are honest; see the README.
        return {0xFF: "A8B8G8R8", 0xFF0000: "A8R8G8B8"}.get(hdr.rmask, "?")
    return "?"


def channel_order(hdr):
    """Byte order of a 32-bit texture as an (r, g, b, a) index tuple.

    Raises UnrecognizedPixelFormatError instead of guessing when the R mask
    is neither shipped value -- silently falling through to one order would
    decode a file to plausible-looking, wrong pixels.
    """
    if hdr.rmask == 0xFF:
        return (0, 1, 2, 3)
    if hdr.rmask == 0xFF0000:
        return (2, 1, 0, 3)
    raise UnrecognizedPixelFormatError(
        "unrecognized 32-bit R mask 0x%x" % hdr.rmask)
