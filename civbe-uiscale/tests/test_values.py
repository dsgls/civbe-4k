"""The coordinate-value grammar.

Beyond Earth's UI XML separates coordinate components with EITHER ',' or '.'
-- both are delimiters, neither is a decimal point. `AnchorSide="I.O"` and
`Size="300.200"` (a 300x200 sprite) are the proof. Treating a dotted pair as
a float is what mangles `45.45` (45x45) into `90.9` (90x9).
"""
import pytest

from civbe_uiscale.values import scale_value


class TestCommaSeparated:
    def test_scales_both_components(self):
        assert scale_value("100,50", 2.0) == "200,100"

    def test_scales_single_component(self):
        assert scale_value("300", 2.0) == "600"

    def test_preserves_negative_components(self):
        assert scale_value("-3,10", 2.0) == "-6,20"

    def test_preserves_whitespace_padding(self):
        assert scale_value(" 10 , 20 ", 2.0) == " 20 , 40 "


class TestDotSeparated:
    def test_dot_is_a_separator_not_a_decimal_point(self):
        assert scale_value("45.45", 2.0) == "90.90"

    def test_keeps_component_that_doubles_into_three_digits(self):
        assert scale_value("300.200", 2.0) == "600.400"

    def test_does_not_lose_component_to_carry(self):
        # 81.7 as a float doubles to 163.4 -- 163x4 instead of 162x14.
        assert scale_value("81.7", 2.0) == "162.14"

    def test_does_not_drop_trailing_zero_component(self):
        # 80.80 as a float is 80.8 -> 161.6, i.e. 161x6 instead of 160x160.
        assert scale_value("80.80", 2.0) == "160.160"

    def test_does_not_collapse_pair_into_single_value(self):
        # 355.5 as a float doubles to 711.0, losing the height entirely.
        assert scale_value("355.5", 2.0) == "710.10"

    def test_zero_component_survives(self):
        assert scale_value("0.0", 2.0) == "0.0"


class TestKeywords:
    def test_bare_keyword_is_untouched(self):
        assert scale_value("parent", 2.0) == "parent"

    def test_keyword_pair_is_untouched(self):
        assert scale_value("parent,parent", 2.0) == "parent,parent"

    def test_full_is_untouched(self):
        assert scale_value("Full,Full", 2.0) == "Full,Full"

    def test_scales_offset_applied_to_keyword(self):
        assert scale_value("parent-40,505", 2.0) == "parent-80,1010"

    def test_scales_addition_offset_on_keyword(self):
        assert scale_value("parent+15", 2.0) == "parent+30"

    def test_mixed_keyword_and_number(self):
        assert scale_value("parent,120", 2.0) == "parent,240"


class TestRounding:
    def test_rounds_half_away_from_zero(self):
        assert scale_value("45,45", 1.5) == "68,68"  # 67.5 -> 68

    def test_rounds_negative_half_away_from_zero(self):
        assert scale_value("-45", 1.5) == "-68"

    def test_identity_scale_is_a_no_op(self):
        assert scale_value("161.11", 1.0) == "161.11"


class TestMalformedInputIsLeftAlone:
    """Anything the grammar does not recognise must pass through untouched --
    silently mangling an unexpected shape is the failure mode being fixed."""

    def test_leading_dot_value_untouched(self):
        assert scale_value(".99", 2.0) == ".99"

    def test_empty_value_untouched(self):
        assert scale_value("", 2.0) == ""

    def test_trailing_separator_untouched(self):
        assert scale_value("64,", 2.0) == "64,"

    def test_non_numeric_junk_untouched(self):
        assert scale_value("TXT_KEY_THING", 2.0) == "TXT_KEY_THING"


class TestReportsWhetherItChanged:
    def test_scale_value_changed_reports_true_on_change(self):
        from civbe_uiscale.values import scale_value_checked

        assert scale_value_checked("10,10", 2.0) == ("20,20", True)

    def test_scale_value_changed_reports_false_when_untouched(self):
        from civbe_uiscale.values import scale_value_checked

        assert scale_value_checked("parent", 2.0) == ("parent", False)
