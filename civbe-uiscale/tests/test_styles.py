"""Reading the named styles a control inherits from."""
from civbe_uiscale import styles

SHEET = """<?xml version="1.0" encoding="utf-8"?>
<StyleSheet>
  <ScrollBarUp Texture="ScrollBarUp.dds" Size="21,19" />
  <NextButtonFlag SliceCorner="135,15" SliceTextureSize="294,45">
    <Label Offset="4,4" FontSize="18"/>
  </NextButtonFlag>
  <ArtifactSlotGrid Style="NextButtonFlag" Size="163,180" />
</StyleSheet>
"""


class TestParse:
    def test_reads_one_definition_per_top_level_tag(self):
        assert set(styles.parse(SHEET)) == {
            "ScrollBarUp", "NextButtonFlag", "ArtifactSlotGrid"}

    def test_keeps_the_attributes_of_a_definition(self):
        assert styles.parse(SHEET)["ScrollBarUp"]["Size"] == "21,19"

    def test_ignores_the_children_of_a_composite_definition(self):
        assert "Label" not in styles.parse(SHEET)

    def test_a_file_that_is_not_a_stylesheet_defines_nothing(self):
        assert styles.parse('<Context><Box Size="10,10"/></Context>') == {}

    def test_survives_a_comment_before_the_root(self):
        assert styles.parse("<!-- hi -->\n" + SHEET) != {}


class TestFlatten:
    def test_a_style_inherits_from_the_one_it_names(self):
        flat = styles.flatten(styles.parse(SHEET))
        assert flat["ArtifactSlotGrid"]["SliceCorner"] == "135,15"

    def test_its_own_attributes_win(self):
        flat = styles.flatten(styles.parse(SHEET))
        assert flat["ArtifactSlotGrid"]["Size"] == "163,180"

    def test_an_unknown_parent_is_not_an_error(self):
        flat = styles.flatten({"A": {"Style": "Missing", "Size": "1,1"}})
        assert flat["A"] == {"Style": "Missing", "Size": "1,1"}

    def test_a_cycle_terminates(self):
        flat = styles.flatten({"A": {"Style": "B"}, "B": {"Style": "A", "Size": "2,2"}})
        assert flat["A"]["Size"] == "2,2"


class TestCollect:
    def test_merges_every_stylesheet_in_the_tree(self, tmp_path):
        (tmp_path / "Debug").mkdir()
        (tmp_path / "Styles.xml").write_text(SHEET)
        (tmp_path / "Debug" / "CoreStyles.xml").write_text(
            '<StyleSheet><CoreButton Size="9,9"/></StyleSheet>')
        table = styles.collect(tmp_path)
        assert "ScrollBarUp" in table and "CoreButton" in table

    def test_skips_files_that_are_not_stylesheets(self, tmp_path):
        (tmp_path / "Panel.xml").write_text('<Context><Box Size="1,1"/></Context>')
        assert styles.collect(tmp_path) == {}
