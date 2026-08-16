"""Shared locations. Edit GAME if the install moves."""
import os

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Where the game is installed. Only needed for the IconTextureAtlases database
# and for running the UI sweep against a live install.
GAME = "/mnt/c/Steam/steamapps/common/Sid Meier's Civilization Beyond Earth"

# Stock Assets/UI, kept so the analysis is reproducible without the game.
STOCK_UI = os.path.join(PROJECT, "reference", "assets-ui-stock")

# Per-archive extractions and the decoded PNGs.
EXTRACTED = os.path.join(PROJECT, "extracted")

TOOL = os.path.join(PROJECT, "civbe-uiscale")
TEXTURE_LIST = os.path.join(PROJECT, "ui_textures.txt")

ATLAS_DBS = [
    os.path.join(GAME, "assets/Gameplay/XML/GameInfo/CivBEIconTextureAtlases.xml"),
    os.path.join(GAME, "assets/DLC/Expansion1/Gameplay/XML/GameInfo/CivBEIconTextureAtlases.xml"),
]
