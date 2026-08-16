"""Rewriting UI XML in place.

Only the matched attribute values are replaced; every other byte of the file
-- indentation, comments, line endings, byte-order marks -- survives intact.
"""
from civbe_uiscale.classify import Space
from civbe_uiscale.xmlpatch import patch_xml


def patch(text, ui=2.0, texture=1.0):
    return patch_xml(text, ui_scale=ui, texture_scale=texture)


class TestScreenGeometry:
    def test_scales_offset_and_size(self):
        out, _ = patch('<Box Offset="10,20" Size="100,50"/>')
        assert out == '<Box Offset="20,40" Size="200,100"/>'

    def test_preserves_original_whitespace_between_attributes(self):
        src = '<Grid\tID="Thing"\t\tOffset="4,4"     Size="10,10" />'
        out, _ = patch(src)
        assert out == '<Grid\tID="Thing"\t\tOffset="8,8"     Size="20,20" />'

    def test_leaves_unclassified_attributes_untouched(self):
        src = '<Label Color="255,0,0,100" MaxLength="255" WrapWidth="300"/>'
        out, _ = patch(src)
        assert out == '<Label Color="255,0,0,100" MaxLength="255" WrapWidth="600"/>'

    def test_scales_dotted_coordinate_pairs_correctly(self):
        out, _ = patch('<Image Size="45.45"/>')
        assert out == '<Image Size="90.90"/>'


class TestTextureSpace:
    def test_texture_coordinates_are_frozen_by_default(self):
        src = '<Image TextureOffset="8,0" Size="8,16" Texture="buttonsides.dds"/>'
        out, _ = patch(src, ui=2.0, texture=1.0)
        assert out == src

    def test_texture_coordinates_follow_the_texture_scale(self):
        src = '<Image TextureOffset="8,0" Size="8,16" Texture="buttonsides.dds"/>'
        out, _ = patch(src, ui=2.0, texture=2.0)
        assert out == '<Image TextureOffset="16,0" Size="16,32" Texture="buttonsides.dds"/>'

    def test_screen_geometry_still_scales_when_textures_are_frozen(self):
        src = '<Image TextureOffset="8,0" Size="8,16" Offset="30,30"/>'
        out, _ = patch(src, ui=2.0, texture=1.0)
        assert out == '<Image TextureOffset="8,0" Size="8,16" Offset="60,60"/>'

    def test_flipbook_sheet_stays_coherent(self):
        src = '<FlipAnim Size="64,64" StepSize="64,0" FrameCount="35" Offset="0,45"/>'
        out, _ = patch(src, ui=2.0, texture=1.0)
        assert out == '<FlipAnim Size="64,64" StepSize="64,0" FrameCount="35" Offset="0,90"/>'


class TestThingsThatMustNotBeTouched:
    def test_ignores_attributes_inside_comments(self):
        src = '<!-- <Box Size="100,50"/> -->\n<Box Size="100,50"/>'
        out, _ = patch(src)
        assert out == '<!-- <Box Size="100,50"/> -->\n<Box Size="200,100"/>'

    def test_ignores_multi_line_comments(self):
        src = '<!--\n<Box Size="10,10"/>\n-->\n<Box Size="10,10"/>'
        out, _ = patch(src)
        assert out.startswith('<!--\n<Box Size="10,10"/>\n-->')
        assert out.endswith('<Box Size="20,20"/>')

    def test_leaves_the_xml_declaration_alone(self):
        src = '<?xml version="1.0" encoding="utf-8"?>\n<Box Size="10,10"/>'
        out, _ = patch(src)
        assert out.startswith('<?xml version="1.0" encoding="utf-8"?>')

    def test_preserves_a_byte_order_mark(self):
        src = '﻿<?xml version="1.0"?>\n<Box Size="10,10"/>'
        out, _ = patch(src)
        assert out.startswith("﻿")

    def test_preserves_crlf_line_endings(self):
        src = '<Box Size="10,10"/>\r\n<Box Size="20,20"/>\r\n'
        out, _ = patch(src)
        assert out == '<Box Size="20,20"/>\r\n<Box Size="40,40"/>\r\n'

    def test_ignores_cdata_sections(self):
        src = '<Text><![CDATA[ Size="10,10" ]]></Text>'
        out, _ = patch(src)
        assert out == src

    def test_handles_a_value_containing_an_angle_bracket(self):
        src = '<Label String="a > b" Size="10,10"/>'
        out, _ = patch(src)
        assert out == '<Label String="a > b" Size="20,20"/>'


class TestChangeReport:
    def test_reports_each_rewritten_value(self):
        out, changes = patch('<Box Offset="10,20" Size="100,50" Color="1,2,3,4"/>')
        assert len(changes) == 2
        by_attr = {c.attr: c for c in changes}
        assert by_attr["Offset"].old == "10,20"
        assert by_attr["Offset"].new == "20,40"
        assert by_attr["Offset"].element == "Box"
        assert by_attr["Offset"].space is Space.SCREEN

    def test_reports_the_line_number(self):
        out, changes = patch('<A/>\n<B/>\n<Box Size="10,10"/>')
        assert changes[0].line == 3

    def test_reports_nothing_when_nothing_changes(self):
        out, changes = patch('<Box Color="1,2,3,4"/>')
        assert changes == []

    def test_distinguishes_texture_space_changes(self):
        out, changes = patch('<Image TextureOffset="8,0"/>', ui=2.0, texture=2.0)
        assert changes[0].space is Space.TEXTURE


class TestInheritedStyles:
    """A control's Style= carries the markers that decide how Size is read."""

    ARROWS = {"ForwardButton": {"Texture": "UnitPanelArrows.dds",
                                "TextureOffset": "45,0",
                                "StateOffsetIncrement": "45,0"}}
    FLAG = {"NextButtonFlag": {"SliceCorner": "135,15",
                               "SliceTextureSize": "294,45"}}

    def test_an_inherited_atlas_offset_freezes_size(self):
        src = '<Button Size="45,45" Style="ForwardButton"/>'
        out, _ = patch_xml(src, 2.0, 1.0, self.ARROWS)
        assert out == src

    def test_inherited_slicing_keeps_size_screen_space(self):
        src = '<GridButton Size="200,45" StateOffsetIncrement="0,0" Style="NextButtonFlag"/>'
        out, _ = patch_xml(src, 2.0, 1.0, self.FLAG)
        assert 'Size="400,90"' in out

    def test_the_elements_own_markers_still_win(self):
        src = '<Button Size="45,45" TextureOffset="0,0" Style="Plain"/>'
        out, _ = patch_xml(src, 2.0, 1.0, {"Plain": {"Texture": "x.dds"}})
        assert out == src

    def test_an_unknown_style_name_is_harmless(self):
        src = '<Button Size="45,45" Style="Missing"/>'
        out, _ = patch_xml(src, 2.0, 1.0, {})
        assert 'Size="90,90"' in out

    def test_only_the_elements_own_values_are_rewritten(self):
        src = '<Button Style="ForwardButton" Offset="10,10"/>'
        out, _ = patch_xml(src, 2.0, 1.0, self.ARROWS)
        assert out == '<Button Style="ForwardButton" Offset="20,20"/>'
