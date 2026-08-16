"""The decoded-image type every civbe_dds module trades in."""
from dataclasses import dataclass


@dataclass
class Image:
    """A decoded level-0 texture, always RGBA regardless of the source's
    on-disk channel order or codec."""
    width: int
    height: int
    rgba: bytes    # R,G,B,A bytes, width * height * 4 long
    group: str      # FTXT usage name ("Interface", ...), "" when absent
