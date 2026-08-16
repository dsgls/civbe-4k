"""Image -> plain, single-level A8B8G8R8 .dds.

The only pixel format civbe_dds writes -- see *Encoding* in the design spec.
A8B8G8R8's byte order in memory is R,G,B,A, matching `Image.rgba` directly,
so pixel data is written verbatim with no channel reordering.
"""
from .header import build_header


def write(path, image, group=None):
    """Write `image` to `path` as a plain, single-level A8B8G8R8 DDS.

    `group` falls back to `image.group`, then to "Interface"
    (`build_header`'s default).
    """
    hdr = build_header(image.width, image.height, group=group or image.group)
    with open(path, "wb") as fh:
        fh.write(hdr)
        fh.write(image.rgba)
