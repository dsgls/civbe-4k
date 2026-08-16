"""Which coordinate space each attribute lives in.

Screen-space values scale with the UI; texture-space values are coordinates
into a .dds and may only scale when the textures themselves are rescaled.
Anything not explicitly classified is left alone.
"""
from civbe_uiscale.classify import Space, classify


class TestScreenSpace:
    def test_offset_is_screen_space(self):
        assert classify("Image", "Offset", {"Offset": "10,10"}) is Space.SCREEN

    def test_plain_size_is_screen_space(self):
        assert classify("Box", "Size", {"Size": "164,210"}) is Space.SCREEN

    def test_padding_is_screen_space(self):
        assert classify("Stack", "Padding", {"Padding": "8"}) is Space.SCREEN

    def test_wrap_width_is_screen_space(self):
        assert classify("Label", "WrapWidth", {"WrapWidth": "300"}) is Space.SCREEN

    def test_font_size_is_screen_space(self):
        assert classify("Label", "FontSize", {"FontSize": "16"}) is Space.SCREEN

    def test_scrollbar_length_is_screen_space(self):
        assert classify("ScrollBar", "Length", {"Length": "620"}) is Space.SCREEN

    def test_slide_anim_travel_is_screen_space(self):
        attrs = {"Start": "0,400", "End": "0,20"}
        assert classify("SlideAnim", "Start", attrs) is Space.SCREEN
        assert classify("SlideAnim", "End", attrs) is Space.SCREEN

    def test_line_geometry_is_screen_space(self):
        attrs = {"Start": "0,0", "End": "10,200", "Width": "1"}
        assert classify("Line", "Start", attrs) is Space.SCREEN
        assert classify("Line", "Width", attrs) is Space.SCREEN

    def test_a_slide_defined_as_a_named_style_travels_too(self):
        # Rising Tide defines its slides as styles, so the element name is the
        # style's -- Start/End beside a Cycle is what identifies one.
        attrs = {"Start": "-20,0", "End": "0,0", "Cycle": "Once", "Speed": "1"}
        assert classify("DiploSlideH", "Start", attrs) is Space.SCREEN
        assert classify("DiploSlideH", "End", attrs) is Space.SCREEN

    def test_a_start_without_travel_is_still_left_alone(self):
        assert classify("Whatever", "Start", {"Start": "4"}) is Space.NONE


class TestTextureSpace:
    def test_texture_offset_is_texture_space(self):
        assert classify("Image", "TextureOffset", {"TextureOffset": "8,0"}) is Space.TEXTURE

    def test_state_offset_increment_is_texture_space(self):
        attrs = {"StateOffsetIncrement": "0,32"}
        assert classify("GridButton", "StateOffsetIncrement", attrs) is Space.TEXTURE

    def test_slice_attributes_are_texture_space(self):
        for attr in ("SliceCorner", "SliceSize", "SliceTextureSize", "SliceStart"):
            assert classify("Grid", attr, {attr: "2,2"}) is Space.TEXTURE

    def test_nine_grid_piece_sizes_are_texture_space(self):
        for attr in ("ULSize", "UCSize", "URSize", "LSize", "CSize", "RSize",
                     "LLSize", "LCSize", "LRSize"):
            assert classify("Grid9DialogBackground", attr, {attr: "48,48"}) is Space.TEXTURE

    def test_nine_grid_tex_starts_are_texture_space(self):
        for attr in ("ULTexStart", "UCTexStart", "URTexStart", "LTexStart",
                     "CTexStart", "RTexStart", "LLTexStart", "LCTexStart", "LRTexStart"):
            assert classify("Grid9DialogBackground", attr, {attr: "0,0"}) is Space.TEXTURE

    def test_flipbook_step_is_texture_space(self):
        attrs = {"Size": "64,64", "StepSize": "64,0", "FrameCount": "35"}
        assert classify("FlipAnim", "StepSize", attrs) is Space.TEXTURE

    def test_flipbook_cell_size_is_texture_space(self):
        attrs = {"Size": "64,64", "StepSize": "64,0", "FrameCount": "35"}
        assert classify("FlipAnim", "Size", attrs) is Space.TEXTURE

    def test_font_icon_cell_is_texture_space(self):
        attrs = {"Start": "22,0", "Size": "22,22", "Advance": "22", "Baseline": "0,4"}
        for attr in ("Start", "Size", "Advance", "Baseline"):
            assert classify("Icon", attr, attrs) is Space.TEXTURE


class TestSizeIsContextDependent:
    """`Size` is the sampled source rect when the control reads a sub-rect of an
    atlas, but the drawn size when the texture is stretched or 9-sliced."""

    def test_size_beside_texture_offset_is_a_source_rect(self):
        attrs = {"Size": "8,16", "TextureOffset": "8,0", "Texture": "buttonsides.dds"}
        assert classify("Image", "Size", attrs) is Space.TEXTURE

    def test_size_beside_state_offset_increment_is_a_source_rect(self):
        attrs = {"Size": "45,45", "StateOffsetIncrement": "0,45"}
        assert classify("Button", "Size", attrs) is Space.TEXTURE

    def test_nine_slice_overrides_the_source_rect_rule(self):
        # A 9-sliced control stretches its texture, so Size is the drawn size
        # even though StateOffsetIncrement picks the state row.
        attrs = {
            "Size": "16,16",
            "StateOffsetIncrement": "0,16",
            "SliceCorner": "6,6",
            "SliceTextureSize": "16,16",
        }
        assert classify("VertShuttle", "Size", attrs) is Space.SCREEN

    def test_size_with_a_plain_texture_is_screen_space(self):
        attrs = {"Size": "45,45", "Texture": "MainOpen.dds"}
        assert classify("Image", "Size", attrs) is Space.SCREEN

    def test_the_per_piece_nine_grid_form_also_overrides_it(self):
        # Most of the game's 9-grids name each piece instead of using
        # SliceCorner. Scrollbar shuttles and slider thumbs are authored this
        # way, and they stretch just the same.
        attrs = {
            "Size": "16,16",
            "StateOffsetIncrement": "0,18",
            "LSize": "3,18", "CSize": "12,18", "RSize": "3,18",
        }
        assert classify("Grid3Shuttle", "Size", attrs) is Space.SCREEN

    def test_markers_inherited_from_a_style_count(self):
        # The End Turn button carries its slicing entirely in NextButtonFlag.
        # classify() is handed the effective attributes, so the button scales.
        attrs = {
            "Size": "Parent-2,45",
            "StateOffsetIncrement": "0,0",
            "Style": "NextButtonFlag",
            "SliceCorner": "135,15",
            "SliceTextureSize": "294,45",
        }
        assert classify("GridButton", "Size", attrs) is Space.SCREEN

    def test_an_atlas_marker_inherited_from_a_style_freezes_size(self):
        # UnitPanelArrows.dds is a 2x2 sheet of 45px arrows; the cycle buttons
        # inherit the offset from ForwardButton and must not double.
        attrs = {
            "Size": "45,45",
            "Style": "ForwardButton",
            "Texture": "UnitPanelArrows.dds",
            "TextureOffset": "45,0",
            "StateOffsetIncrement": "45,0",
        }
        assert classify("Button", "Size", attrs) is Space.TEXTURE


class TestUnclassifiedAttributesAreLeftAlone:
    def test_colors_are_never_scaled(self):
        for attr in ("Color", "Color0", "Color1", "CursorColor", "HighlightColor"):
            assert classify("Label", attr, {attr: "255,0,0,100"}) is Space.NONE

    def test_character_limit_is_not_a_pixel_count(self):
        assert classify("EditBox", "MaxLength", {"MaxLength": "255"}) is Space.NONE

    def test_frame_counts_are_not_pixels(self):
        attrs = {"Columns": "7", "FrameCount": "35"}
        assert classify("FlipAnim", "Columns", attrs) is Space.NONE
        assert classify("FlipAnim", "FrameCount", attrs) is Space.NONE

    def test_animation_timing_is_not_geometry(self):
        for attr in ("Speed", "Pause", "AlphaStart", "AlphaEnd"):
            assert classify("AlphaAnim", attr, {attr: "0.5"}) is Space.NONE

    def test_booleans_and_flags_are_left_alone(self):
        for attr in ("Hidden", "Vertical", "ConsumeMouse", "Void1"):
            assert classify("Box", attr, {attr: "1"}) is Space.NONE

    def test_unknown_attribute_defaults_to_untouched(self):
        assert classify("Whatever", "SomeNewAttribute", {"SomeNewAttribute": "12"}) is Space.NONE
