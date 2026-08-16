"""Public API: read/write DDS and PNG textures without importing submodules.

See *Public API* in the design spec for the contract each of these keeps.
"""
from .decode import read
from .encode import write
from .header import header
from .image import Image
from .png import read_png, write_png

__all__ = ["Image", "read", "write", "header", "read_png", "write_png"]
