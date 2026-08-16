"""Shared locations. Edit GAME if the install moves."""
import os

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Where the game is installed. Only needed for the IconTextureAtlases database
# and for running the UI sweep against a live install.
GAME = "/mnt/c/Steam/steamapps/common/Sid Meier's Civilization Beyond Earth"

# Stock Assets/UI, kept so the analysis is reproducible without the game.
STOCK_UI = os.path.join(PROJECT, "reference", "assets-ui-stock")

# Every stock UI tree, keyed by the name the sweep gives it, with the
# install-relative path the patched copy lives at.
STOCK_TREES = {
    "base": (STOCK_UI, ("assets", "UI")),
    "Expansion1": (
        os.path.join(PROJECT, "reference", "assets-dlc-expansion1-ui-stock"),
        ("assets", "DLC", "Expansion1", "UI"),
    ),
}

# Per-archive extractions and the decoded PNGs.
EXTRACTED = os.path.join(PROJECT, "extracted")

TOOL = os.path.join(PROJECT, "civbe-uiscale")
DDS_TOOL = os.path.join(PROJECT, "civbe-dds")
TEXTURE_LIST = os.path.join(PROJECT, "ui_textures.txt")

ATLAS_DBS = [
    os.path.join(GAME, "assets/Gameplay/XML/GameInfo/CivBEIconTextureAtlases.xml"),
    os.path.join(GAME, "assets/DLC/Expansion1/Gameplay/XML/GameInfo/CivBEIconTextureAtlases.xml"),
]
