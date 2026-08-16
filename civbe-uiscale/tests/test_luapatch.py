"""Rewriting hardcoded layout calls in the UI Lua.

Only calls whose arguments are all numeric literals can be rewritten; a call
with a computed argument is left alone because its inputs already come from
scaled controls.
"""
from civbe_uiscale.classify import Space
from civbe_uiscale.luapatch import patch_icon_support, patch_lua


def patch(text, ui=2.0, texture=1.0):
    return patch_lua(text, ui_scale=ui, texture_scale=texture)


class TestScreenSetters:
    def test_scales_a_two_argument_setter(self):
        out, _ = patch("control:SetOffsetVal(10, 20);")
        assert out == "control:SetOffsetVal(20, 40);"

    def test_scales_a_one_argument_setter(self):
        out, _ = patch("control:SetSizeY(85);")
        assert out == "control:SetSizeY(170);"

    def test_preserves_the_original_spacing(self):
        out, _ = patch("control:SetOffsetVal( 450,32 );")
        assert out == "control:SetOffsetVal( 900,64 );"

    def test_preserves_negative_arguments(self):
        out, _ = patch("control:SetOffsetVal( -1, 0 );")
        assert out == "control:SetOffsetVal( -2, 0 );"

    def test_scales_wrap_width(self):
        out, _ = patch("Controls.Label:SetWrapWidth( 400 );")
        assert out == "Controls.Label:SetWrapWidth( 800 );"


class TestCallsThatMustNotChange:
    def test_leaves_computed_arguments_alone(self):
        src = "Controls.X:SetOffsetVal(12, parentSizeY - 20);"
        out, _ = patch(src)
        assert out == src

    def test_leaves_unlisted_setters_alone(self):
        src = "bar:SetPercent(0.5); icon:SetAlpha(1); c:SetScrollValue(120);"
        out, _ = patch(src)
        assert out == src

    def test_leaves_icon_hookup_arguments_alone(self):
        # The size argument is a database key into IconTextureAtlases, not a
        # pixel measurement -- scaling it makes the lookup miss.
        src = "IconHookup(perkInfo.PortraitIndex, 56, perkInfo.IconAtlas, perkIcon);"
        out, _ = patch(src)
        assert out == src

    def test_ignores_line_comments(self):
        src = "-- Controls.Panel:SetOffsetVal( 40, 44 );\nControls.Panel:SetOffsetVal(40, 44);"
        out, _ = patch(src)
        assert out == "-- Controls.Panel:SetOffsetVal( 40, 44 );\nControls.Panel:SetOffsetVal(80, 88);"

    def test_ignores_block_comments(self):
        src = "--[[\nc:SetSizeY(10);\n]]\nc:SetSizeY(10);"
        out, _ = patch(src)
        assert out.startswith("--[[\nc:SetSizeY(10);\n]]")
        assert out.endswith("c:SetSizeY(20);")

    def test_does_not_match_a_longer_identifier(self):
        src = "obj:MySetSizeY(10);"
        out, _ = patch(src)
        assert out == src


class TestTextureSetters:
    def test_texture_setters_are_frozen_by_default(self):
        src = "c:SetTextureOffsetVal(0, 96);"
        out, _ = patch(src, ui=2.0, texture=1.0)
        assert out == src

    def test_texture_setters_follow_the_texture_scale(self):
        out, _ = patch("c:SetTextureOffsetVal(0, 96);", ui=2.0, texture=2.0)
        assert out == "c:SetTextureOffsetVal(0, 192);"

    def test_texture_size_is_texture_space(self):
        out, _ = patch("c:SetTextureSizeVal(48,1);", ui=2.0, texture=2.0)
        assert out == "c:SetTextureSizeVal(96,2);"


class TestChangeReport:
    def test_reports_each_rewritten_call(self):
        out, changes = patch("c:SetOffsetVal(10, 20);")
        assert len(changes) == 1
        assert changes[0].call == "SetOffsetVal"
        assert changes[0].old == "10, 20"
        assert changes[0].new == "20, 40"
        assert changes[0].space is Space.SCREEN

    def test_reports_the_line_number(self):
        out, changes = patch("x = 1\ny = 2\nc:SetSizeY(5);")
        assert changes[0].line == 3


class TestIconSupportChokepoint:
    """IconHookup computes an atlas offset as cell_index * iconSize. When the
    atlases are rescaled, that arithmetic -- not the database key -- is what
    has to change."""

    LOOKUP = ("\t\t\treturn Vector2( (offset % numCols) * iconSize, "
              "math.floor(offset / numCols) * iconSize ), filename;\n")
    HOOKUP = ("\t\t\timageControl:SetTextureOffsetVal( (offset % numCols) * iconSize, "
              "math.floor(offset / numCols) * iconSize );\n")

    def test_scales_the_computed_atlas_offset(self):
        out, count = patch_icon_support(self.LOOKUP + self.HOOKUP, texture_scale=2.0)
        assert "(offset % numCols) * iconSize * 2" in out
        assert "math.floor(offset / numCols) * iconSize * 2" in out
        assert count == 4

    def test_leaves_the_database_key_untouched(self):
        out, _ = patch_icon_support("local entry = atlas[iconSize];", texture_scale=2.0)
        assert out == "local entry = atlas[iconSize];"

    def test_pins_the_control_to_one_atlas_cell(self):
        src = self.HOOKUP
        out, _ = patch_icon_support(src, texture_scale=2.0, pin_icon_size=True)
        assert "imageControl:SetSizeVal( iconSize * 2, iconSize * 2 );" in out

    def test_pinning_uses_native_size_when_textures_are_unscaled(self):
        out, _ = patch_icon_support(self.HOOKUP, texture_scale=1.0, pin_icon_size=True)
        assert "imageControl:SetSizeVal( iconSize * 1, iconSize * 1 );" in out

    def test_pinning_can_be_disabled(self):
        out, _ = patch_icon_support(self.HOOKUP, texture_scale=2.0, pin_icon_size=False)
        assert "SetSizeVal" not in out

    def test_is_not_applied_twice(self):
        once, _ = patch_icon_support(self.HOOKUP, texture_scale=2.0, pin_icon_size=True)
        twice, count = patch_icon_support(once, texture_scale=2.0, pin_icon_size=True)
        assert twice == once
        assert count == 0
