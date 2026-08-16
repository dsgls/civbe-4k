"""Per-site rewrites for Lua the generic patcher cannot reach.

A site rule names its file and the exact source text to scale, so these tests
drive the mechanism with a synthetic table; the shipped table is checked for
shape here and against the stock trees by analysis/verify_lua_sites.py.
"""
from civbe_uiscale.classify import Space
from civbe_uiscale.luasites import SITES, Rule, patch_sites

TABLE = {
    "InGame/Fake.lua": (
        Rule(Space.TEXTURE, "local OFF = 64;", "local OFF = 64 * {s};"),
        Rule(Space.SCREEN, "local RADIUS = 400;", "local RADIUS = 400 * {s};"),
    ),
}


class TestMechanism:
    def test_texture_rule_follows_texture_scale(self):
        out, changes = patch_sites(
            "InGame/Fake.lua", "local OFF = 64;\n", 2.0, 2.0, sites=TABLE)
        assert out == "local OFF = 64 * 2;\n"
        assert changes[0].space is Space.TEXTURE

    def test_texture_rule_is_inert_at_texture_scale_one(self):
        src = "local OFF = 64;\n"
        out, changes = patch_sites("InGame/Fake.lua", src, 2.0, 1.0, sites=TABLE)
        assert out == src
        assert changes == []

    def test_screen_rule_follows_ui_scale(self):
        out, _ = patch_sites(
            "InGame/Fake.lua", "local RADIUS = 400;\n", 2.0, 1.0, sites=TABLE)
        assert out == "local RADIUS = 400 * 2;\n"

    def test_replaces_every_occurrence(self):
        src = "local OFF = 64;\nlocal OFF = 64;\n"
        out, changes = patch_sites("InGame/Fake.lua", src, 2.0, 2.0, sites=TABLE)
        assert out.count("* 2") == 2
        assert [change.line for change in changes] == [1, 2]

    def test_unknown_file_is_untouched(self):
        src = "local OFF = 64;\n"
        out, changes = patch_sites("InGame/Other.lua", src, 2.0, 2.0, sites=TABLE)
        assert out == src
        assert changes == []

    def test_fractional_scale_is_written_as_a_float(self):
        out, _ = patch_sites(
            "InGame/Fake.lua", "local OFF = 64;\n", 1.0, 1.5, sites=TABLE)
        assert out == "local OFF = 64 * 1.5;\n"


class TestTechTreeLayout:
    """The tech-web spread is Lua arithmetic, invisible to the XML sweep, and
    follows the UI scale rather than the texture scale."""

    REL = "InGame/TechTree/TechTree.lua"

    def test_radius_scalar_follows_ui_scale(self):
        src = "local g_radiusScalar\t\t:number = 400;\t\t-- comment\n"
        out, _ = patch_sites(self.REL, src, 2.0, 1.0)
        assert "= 400 * 2;" in out

    def test_radius_scalar_ignores_texture_scale(self):
        src = "local g_radiusScalar\t\t:number = 400;\t\t-- comment\n"
        out, _ = patch_sites(self.REL, src, 1.0, 2.0)
        assert "= 400;" in out

    def test_leaf_offsets_follow_ui_scale(self):
        src = "\t\t\t\t\treturn parentx + 38, parenty + (36 + (i*69));\n"
        out, _ = patch_sites(self.REL, src, 2.0, 1.0)
        assert "38 * 2" in out and "(36 + (i*69)) * 2" in out


class TestShippedTable:
    def test_every_rule_changes_its_text(self):
        for rules in SITES.values():
            for rule in rules:
                assert rule.old != rule.new
                assert "{s}" in rule.new

    def test_keys_are_tree_relative_posix_paths(self):
        for rel in SITES:
            assert "\\" not in rel and not rel.startswith("/")
            assert rel.endswith(".lua")


class TestYieldNumberStrip:
    """The one rule anchored to a line ending: the 768 line has no semicolon.
    Rules assume the LF-normalized vendored trees, not the CRLF stock files."""

    def test_the_unterminated_768_line_is_scaled(self):
        src = "    if( number > 9 ) then\n        y = 768\n    else\n"
        out, _ = patch_sites("InGame/YieldIconManager.lua", src, 2.0, 2.0)
        assert "y = 768 * 2\n" in out
