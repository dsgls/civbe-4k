"""Applying the sweep to a game tree.

Every run re-derives from the pristine backup, so re-running at a different
scale never compounds.
"""
import shutil

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
        assert (backup / "assets" / "UI" / "Styles.xml").read_bytes() == (
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
        assert b'Size="100,50"' in (backup / "assets" / "UI" / "Styles.xml").read_bytes()


class TestTextureScale:
    def test_texture_scale_moves_atlas_coordinates(self, game):
        run(game, game / "backup", ui_scale=2.0, texture_scale=2.0)
        text = (ui_of(game) / "InGame" / "Panel.xml").read_bytes().decode("utf-8-sig")
        assert 'TextureOffset="16,0"' in text
        assert 'Size="16,32"' in text

    def test_counts_texture_changes_separately(self, game):
        report = run(game, game / "backup", ui_scale=2.0, texture_scale=2.0)
        assert report.texture_changes > 0

    def test_applies_the_site_rules_for_computed_offsets(self, game):
        task_list = ui_of(game) / "InGame" / "TaskList.lua"
        task_list.write_bytes(b"local iOffset = 0;\n\t\t\t\tiOffset = 96;\n")
        run(game, game / "backup", ui_scale=2.0, texture_scale=2.0)
        assert b"iOffset = 96 * 2;" in task_list.read_bytes()

    def test_site_rules_are_inert_at_texture_scale_one(self, game):
        task_list = ui_of(game) / "InGame" / "TaskList.lua"
        source = b"local iOffset = 0;\n\t\t\t\tiOffset = 96;\n"
        task_list.write_bytes(source)
        run(game, game / "backup", ui_scale=2.0, texture_scale=1.0)
        assert task_list.read_bytes() == source


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
        assert (front_end / "backup" / "assets" / "DLC" / "Expansion1" / "UI"
                / "FrontEnd" / "MainMenu.xml").read_text() == SLIDE

    def test_scales_the_expansion_menu_geometry(self, front_end):
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0,
            fast_menu=True)
        assert 'Size="560,70"' in expansion_menu(front_end).read_text()

    def test_dropping_the_flag_puts_the_stock_animation_back(self, front_end):
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0,
            fast_menu=True)
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0)
        for menu in (expansion_menu(front_end),
                     ui_of(front_end) / "FrontEnd" / "MainMenu.xml"):
            text = menu.read_text()
            assert 'AlphaStart="0"' in text
            assert 'Start="120,0"' in text

    def test_dry_run_touches_neither_tree(self, front_end):
        report = run(front_end, front_end / "backup", ui_scale=2.0,
                     texture_scale=1.0, fast_menu=True, dry_run=True)
        assert expansion_menu(front_end).read_text() == SLIDE
        assert not (front_end / "backup").exists()
        assert report.fast_menu_edits > 0

    def test_a_missing_expansion_is_not_an_error(self, game):
        report = run(game, game / "backup", ui_scale=2.0, texture_scale=1.0,
                     fast_menu=True)
        assert [tree.name for tree in report.trees] == ["base"]


class TestEveryTree:
    def test_takes_a_pristine_copy_of_every_tree(self, front_end):
        backup = front_end / "backup"
        run(front_end, backup, ui_scale=2.0, texture_scale=1.0)
        assert (backup / "assets" / "UI" / "Styles.xml").exists()
        assert (backup / "assets" / "DLC" / "Expansion1" / "UI" / "FrontEnd"
                / "MainMenu.xml").read_text() == SLIDE

    def test_scales_a_dlc_file_that_shadows_a_base_file(self, front_end):
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0)
        assert 'Size="560,70"' in expansion_menu(front_end).read_text()

    def test_reports_each_tree_separately(self, front_end):
        report = run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0)
        assert [tree.name for tree in report.trees] == ["base", "Expansion1"]
        assert all(tree.files_changed for tree in report.trees)

    def test_details_distinguish_two_trees_at_the_same_path(self, front_end):
        report = run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0)
        menus = {tree for tree, rel, _ in report.details
                 if rel.replace("\\", "/") == "FrontEnd/MainMenu.xml"}
        assert menus == {"base", "Expansion1"}

    def test_skips_a_tree_on_request(self, front_end):
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0,
            skip_trees=["Expansion1"])
        assert expansion_menu(front_end).read_text() == SLIDE
        assert not (front_end / "backup" / "assets" / "DLC").exists()

    def test_a_dlc_installed_later_gets_its_own_backup(self, game):
        backup = game / "backup"
        run(game, backup, ui_scale=2.0, texture_scale=1.0)
        late = game / "assets" / "DLC" / "Expansion1" / "UI" / "FrontEnd"
        late.mkdir(parents=True)
        (late / "MainMenu.xml").write_text(SLIDE)

        run(game, backup, ui_scale=2.0, texture_scale=1.0)
        assert (backup / "assets" / "DLC" / "Expansion1" / "UI" / "FrontEnd"
                / "MainMenu.xml").read_text() == SLIDE
        assert 'Size="560,70"' in (late / "MainMenu.xml").read_text()

    def test_ignores_a_dlc_with_no_ui_directory(self, front_end):
        maps = front_end / "assets" / "DLC" / "DLC_SP_Maps" / "Maps"
        maps.mkdir(parents=True)
        (maps / "Terrain.lua").write_text("Controls.X:SetSizeVal(10, 20);\n")

        report = run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0)
        assert [tree.name for tree in report.trees] == ["base", "Expansion1"]
        assert "SetSizeVal(10, 20)" in (maps / "Terrain.lua").read_text()

    def test_icon_support_is_patched_only_where_it_exists(self, front_end):
        (ui_of(front_end) / "IconSupport.lua").write_text(
            "imageControl:SetTextureOffsetVal( (offset % numCols) * iconSize,"
            " math.floor(offset / numCols) * iconSize );\n"
        )
        report = run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=2.0)
        by_name = {tree.name: tree for tree in report.trees}
        assert by_name["base"].icon_support_edits > 0
        assert by_name["Expansion1"].icon_support_edits == 0


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

    def test_restores_every_tree(self, front_end):
        originals = {
            path: path.read_text()
            for path in front_end.rglob("*.xml") if path.is_file()
        }
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0,
            fast_menu=True)
        restored, orphaned = restore(front_end, front_end / "backup")

        assert dict(restored) == {"base": 5, "Expansion1": 1}
        assert orphaned == []
        for path, text in originals.items():
            assert path.read_text() == text

    def test_tolerates_a_dlc_uninstalled_since_the_backup(self, front_end):
        run(front_end, front_end / "backup", ui_scale=2.0, texture_scale=1.0)
        shutil.rmtree(front_end / "assets" / "DLC" / "Expansion1")

        restored, orphaned = restore(front_end, front_end / "backup")
        assert dict(restored) == {"base": 5}
        assert orphaned == ["Expansion1"]
        assert not (front_end / "assets" / "DLC" / "Expansion1").exists()

    def test_restoring_without_a_backup_is_an_error(self, game):
        with pytest.raises(FileNotFoundError):
            restore(game, game / "nonexistent")
