"""Applying the sweep to a game tree.

Every run re-derives from the pristine backup, so re-running at a different
scale never compounds.
"""
import pytest

from civbe_uiscale.apply import find_ui_dir, restore, run


@pytest.fixture
def game(tmp_path):
    ui = tmp_path / "assets" / "UI"
    (ui / "InGame").mkdir(parents=True)
    (ui / "Styles.xml").write_bytes(
        b'<?xml version="1.0"?>\n<Box Size="100,50" Offset="10,10"/>\n'
    )
    (ui / "InGame" / "Panel.xml").write_bytes(
        '﻿<Image TextureOffset="8,0" Size="8,16" Offset="5,5"/>\n'.encode("utf-8")
    )
    (ui / "InGame" / "Panel.lua").write_bytes(
        b"Controls.X:SetOffsetVal(10, 20);\nControls.Y:SetPercent(0.5);\n"
    )
    return tmp_path


def ui_of(game):
    return find_ui_dir(game)


class TestFirstRun:
    def test_takes_a_pristine_backup(self, game):
        backup = game / "backup"
        run(game, backup, ui_scale=2.0, texture_scale=1.0)
        assert (backup / "Styles.xml").read_bytes() == (
            b'<?xml version="1.0"?>\n<Box Size="100,50" Offset="10,10"/>\n'
        )

    def test_scales_screen_geometry(self, game):
        run(game, game / "backup", ui_scale=2.0, texture_scale=1.0)
        assert b'Size="200,100"' in (ui_of(game) / "Styles.xml").read_bytes()

    def test_freezes_texture_coordinates_by_default(self, game):
        run(game, game / "backup", ui_scale=2.0, texture_scale=1.0)
        text = (ui_of(game) / "InGame" / "Panel.xml").read_bytes().decode("utf-8-sig")
        assert 'TextureOffset="8,0"' in text
        assert 'Size="8,16"' in text
        assert 'Offset="10,10"' in text

    def test_scales_lua_layout_calls(self, game):
        run(game, game / "backup", ui_scale=2.0, texture_scale=1.0)
        text = (ui_of(game) / "InGame" / "Panel.lua").read_text()
        assert "SetOffsetVal(20, 40)" in text
        assert "SetPercent(0.5)" in text

    def test_preserves_a_byte_order_mark(self, game):
        run(game, game / "backup", ui_scale=2.0, texture_scale=1.0)
        assert (ui_of(game) / "InGame" / "Panel.xml").read_bytes().startswith(b"\xef\xbb\xbf")

    def test_reports_what_it_changed(self, game):
        report = run(game, game / "backup", ui_scale=2.0, texture_scale=1.0)
        assert report.files_changed == 3
        assert report.screen_changes > 0
        assert report.texture_changes == 0


class TestRerunning:
    def test_rerunning_at_the_same_scale_is_stable(self, game):
        run(game, game / "backup", ui_scale=2.0, texture_scale=1.0)
        first = (ui_of(game) / "Styles.xml").read_bytes()
        run(game, game / "backup", ui_scale=2.0, texture_scale=1.0)
        assert (ui_of(game) / "Styles.xml").read_bytes() == first

    def test_rerunning_at_a_new_scale_does_not_compound(self, game):
        run(game, game / "backup", ui_scale=2.0, texture_scale=1.0)
        run(game, game / "backup", ui_scale=3.0, texture_scale=1.0)
        assert b'Size="300,150"' in (ui_of(game) / "Styles.xml").read_bytes()

    def test_an_existing_backup_is_never_overwritten(self, game):
        backup = game / "backup"
        run(game, backup, ui_scale=2.0, texture_scale=1.0)
        run(game, backup, ui_scale=4.0, texture_scale=1.0)
        assert b'Size="100,50"' in (backup / "Styles.xml").read_bytes()


class TestTextureScale:
    def test_texture_scale_moves_atlas_coordinates(self, game):
        run(game, game / "backup", ui_scale=2.0, texture_scale=2.0)
        text = (ui_of(game) / "InGame" / "Panel.xml").read_bytes().decode("utf-8-sig")
        assert 'TextureOffset="16,0"' in text
        assert 'Size="16,32"' in text

    def test_counts_texture_changes_separately(self, game):
        report = run(game, game / "backup", ui_scale=2.0, texture_scale=2.0)
        assert report.texture_changes > 0


class TestDryRun:
    def test_dry_run_leaves_the_tree_untouched(self, game):
        before = (ui_of(game) / "Styles.xml").read_bytes()
        report = run(game, game / "backup", ui_scale=2.0, texture_scale=1.0, dry_run=True)
        assert (ui_of(game) / "Styles.xml").read_bytes() == before
        assert report.files_changed == 3

    def test_dry_run_still_needs_no_backup_to_exist(self, game):
        run(game, game / "backup", ui_scale=2.0, texture_scale=1.0, dry_run=True)
        assert not (game / "backup").exists()


SLIDE = ('<SlideAnim Size="280,35" Start="60,0" End="0,0">'
         '<AlphaAnim AlphaStart="0" AlphaEnd="1"/></SlideAnim>\n')
LEGAL = ("    UIManager:QueuePopup( Controls.LegalScreen, "
         "PopupPriority.LegalScreen );\n")


@pytest.fixture
def front_end(game):
    front = ui_of(game) / "FrontEnd"
    front.mkdir()
    (front / "MainMenu.xml").write_text(SLIDE)
    (front / "FrontEnd.lua").write_text(LEGAL)
    expansion = game / "assets" / "DLC" / "Expansion1" / "UI" / "FrontEnd"
    expansion.mkdir(parents=True)
    (expansion / "MainMenu.xml").write_text(SLIDE)
    return game


def expansion_menu(game):
    return game / "assets" / "DLC" / "Expansion1" / "UI" / "FrontEnd" / "MainMenu.xml"


class TestFastMenu:
    def test_off_by_default(self, front_end):
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0)
        text = (ui_of(front_end) / "FrontEnd" / "MainMenu.xml").read_text()
        assert 'AlphaStart="0"' in text
        assert 'Start="120,0"' in text

    def test_flattens_the_menu_animation(self, front_end):
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0,
            fast_menu=True)
        text = (ui_of(front_end) / "FrontEnd" / "MainMenu.xml").read_text()
        assert 'AlphaStart="1"' in text
        assert 'Start="0,0"' in text

    def test_skips_the_legal_screen(self, front_end):
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0,
            fast_menu=True)
        text = (ui_of(front_end) / "FrontEnd" / "FrontEnd.lua").read_text()
        assert text.lstrip().startswith("-- UIManager:QueuePopup")

    def test_patches_the_expansion_menu_from_its_own_backup(self, front_end):
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0,
            fast_menu=True)
        assert 'Start="0,0"' in expansion_menu(front_end).read_text()
        assert (front_end / "backup-dlc" / "Expansion1" / "UI" / "FrontEnd"
                / "MainMenu.xml").read_text() == SLIDE

    def test_leaves_the_expansion_geometry_alone(self, front_end):
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0,
            fast_menu=True)
        assert 'Size="280,35"' in expansion_menu(front_end).read_text()

    def test_dropping_the_flag_puts_the_stock_menu_back(self, front_end):
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0,
            fast_menu=True)
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0)
        assert expansion_menu(front_end).read_text() == SLIDE
        assert 'AlphaStart="0"' in (
            ui_of(front_end) / "FrontEnd" / "MainMenu.xml").read_text()

    def test_dry_run_touches_neither_tree(self, front_end):
        report = run(front_end, front_end / "backup", ui_scale=2.0,
                     texture_scale=1.0, fast_menu=True, dry_run=True)
        assert expansion_menu(front_end).read_text() == SLIDE
        assert not (front_end / "backup-dlc").exists()
        assert report.fast_menu_edits > 0

    def test_a_missing_expansion_is_not_an_error(self, game):
        run(game, game / "backup", ui_scale=2.0, texture_scale=1.0, fast_menu=True)
        assert not (game / "backup-dlc").exists()


class TestRestore:
    def test_restores_every_byte(self, game):
        originals = {
            p.relative_to(ui_of(game)): p.read_bytes()
            for p in ui_of(game).rglob("*") if p.is_file()
        }
        run(game, game / "backup", ui_scale=2.0, texture_scale=1.0)
        restore(game, game / "backup")
        for rel, data in originals.items():
            assert (ui_of(game) / rel).read_bytes() == data

    def test_restores_the_expansion_menu_too(self, front_end):
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0,
            fast_menu=True)
        restore(front_end, front_end / "backup")
        assert expansion_menu(front_end).read_text() == SLIDE

    def test_restoring_without_a_backup_is_an_error(self, game):
        with pytest.raises(FileNotFoundError):
            restore(game, game / "nonexistent")
