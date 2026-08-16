"""Discovering the UI trees an install carries."""
import pytest

from civbe_uiscale import trees


@pytest.fixture
def game(tmp_path):
    (tmp_path / "assets" / "UI").mkdir(parents=True)
    return tmp_path


def dlc(game, name, subdir="UI"):
    path = game / "assets" / "DLC" / name / subdir
    path.mkdir(parents=True)
    return path


def test_finds_the_base_tree_alone_when_no_dlc_is_installed(game):
    found = trees.discover(game)
    assert [tree.name for tree in found] == ["base"]
    assert found[0].live_dir == game / "assets" / "UI"


def test_finds_a_dlc_tree_next_to_the_base_tree(game):
    dlc(game, "Expansion1")
    found = trees.discover(game)
    assert [tree.name for tree in found] == ["base", "Expansion1"]


def test_orders_the_base_tree_first(game):
    dlc(game, "AExpansion")
    assert trees.discover(game)[0].name == "base"


def test_ignores_a_dlc_directory_with_no_ui_subdir(game):
    dlc(game, "DLC_SP_Maps", subdir="Maps")
    assert [tree.name for tree in trees.discover(game)] == ["base"]


def test_ignores_a_stray_file_among_the_dlc_directories(game):
    dlc(game, "Expansion1")
    (game / "assets" / "DLC" / "readme.txt").write_text("hi\n")
    assert [tree.name for tree in trees.discover(game)] == ["base", "Expansion1"]


def test_matches_directory_casing_the_install_happens_to_use(tmp_path):
    (tmp_path / "Assets" / "ui").mkdir(parents=True)
    (tmp_path / "Assets" / "dlc" / "Expansion1" / "ui").mkdir(parents=True)
    found = trees.discover(tmp_path)
    assert [tree.name for tree in found] == ["base", "Expansion1"]
    assert found[1].live_dir == tmp_path / "Assets" / "dlc" / "Expansion1" / "ui"


def test_backup_paths_are_canonical_whatever_the_install_casing(tmp_path):
    (tmp_path / "Assets" / "ui").mkdir(parents=True)
    (tmp_path / "Assets" / "dlc" / "Expansion1" / "ui").mkdir(parents=True)
    found = trees.discover(tmp_path)
    assert [tree.backup_rel.as_posix() for tree in found] == [
        "assets/UI", "assets/DLC/Expansion1/UI",
    ]


def test_an_install_with_no_dlc_directory_at_all_is_fine(game):
    assert [tree.name for tree in trees.discover(game)] == ["base"]
