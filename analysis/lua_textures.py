"""Resolving which textures a screen's Lua samples by runtime offset.

Controls whose texture offset or size is set from Lua carry no atlas marker in
the XML, so classify.py alone misses their textures. Each
`control:SetTextureOffsetVal/SetTextureSizeVal` call is resolved to the
control's XML element by ID -- the screen's same-name XML first, then its
directory, then the whole tree (instanced controls can be defined in
Styles.xml). ID collisions over-approximate; a stretched texture upscaled by
mistake is harmless, a sampled texture missed is not.

Shared by build_texture_list.py and verify_lua_sites.py.
"""
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paths import TOOL

sys.path.insert(0, TOOL)
from civbe_uiscale.xmlpatch import _ATTR, iter_tags

TEXTURE_REFS = ("Texture", "MaskTexture", "ButtonTexture")

CALL = re.compile(r'([A-Za-z_][\w\.\[\]"]*?)\s*:\s*SetTexture(?:Offset|Size)Val\s*\(')

_LITERAL_SET_TEXTURE = re.compile(r'SetTexture\(\s*"([^"]+)"\s*\)')


def _tree_xmls(root, cache={}):
    if root not in cache:
        cache[root] = [os.path.join(dp, x)
                       for dp, dn, fn in os.walk(root)
                       for x in fn if x.lower().endswith(".xml")]
    return cache[root]


def _id_textures(xml_path, cache={}):
    """ID -> set of texture names, for every element carrying a Texture ref."""
    if xml_path not in cache:
        table = collections.defaultdict(set)
        text = open(xml_path, encoding="utf-8", errors="replace").read()
        for element, s, e, _depth in iter_tags(text):
            attrs = {m.group(1): m.group(2) for m in _ATTR.finditer(text, s, e)}
            cid = attrs.get("ID")
            if cid:
                for key in TEXTURE_REFS:
                    if key in attrs:
                        table[cid].add(attrs[key])
        cache[xml_path] = table
    return cache[xml_path]


def resolve(tree_root, lua_path, text):
    """Texture refs the Lua at `lua_path` samples by runtime offset."""
    refs = set(_LITERAL_SET_TEXTURE.findall(text))
    directory = os.path.dirname(lua_path)
    base_xml = lua_path[:-4] + ".xml"
    fallback = [os.path.join(directory, x) for x in sorted(os.listdir(directory))
                if x.lower().endswith(".xml")]
    for m in CALL.finditer(text):
        cid = re.split(r"[.\[]", m.group(1))[-1].strip('"]')
        hits = _id_textures(base_xml).get(cid, set()) if os.path.exists(base_xml) else set()
        if not hits:
            for xp in fallback:
                hits |= _id_textures(xp).get(cid, set())
        if not hits:
            for xp in _tree_xmls(tree_root):
                hits |= _id_textures(xp).get(cid, set())
        refs |= hits
    return refs
