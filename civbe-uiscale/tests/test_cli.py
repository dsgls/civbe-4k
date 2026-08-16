"""The command line entry point."""
import pytest

from civbe_uiscale.cli import main


@pytest.fixture
def game(tmp_path):
    ui = tmp_path / "assets" / "UI"
    ui.mkdir(parents=True)
    (ui / "Styles.xml").write_bytes(b'<Box Size="100,50"/>\n')
    return tmp_path


def test_apply_scales_the_tree(game, capsys):
    code = main(["apply", "--game-dir", str(game), "--backup", str(game / "bak"),
                 "--scale", "2"])
    assert code == 0
    assert b'Size="200,100"' in (game / "assets" / "UI" / "Styles.xml").read_bytes()


def test_dry_run_changes_nothing_but_still_summarises(game, capsys):
    main(["apply", "--game-dir", str(game), "--backup", str(game / "bak"),
          "--scale", "2", "--dry-run"])
    assert (game / "assets" / "UI" / "Styles.xml").read_bytes() == b'<Box Size="100,50"/>\n'
    assert "1 file" in capsys.readouterr().out


def test_restore_undoes_the_sweep(game):
    main(["apply", "--game-dir", str(game), "--backup", str(game / "bak"), "--scale", "2"])
    main(["restore", "--game-dir", str(game), "--backup", str(game / "bak")])
    assert (game / "assets" / "UI" / "Styles.xml").read_bytes() == b'<Box Size="100,50"/>\n'


def test_writes_a_detailed_report_when_asked(game, tmp_path):
    out = tmp_path / "changes.txt"
    main(["apply", "--game-dir", str(game), "--backup", str(game / "bak"),
          "--scale", "2", "--report", str(out)])
    assert 'Size' in out.read_text()
    assert '100,50' in out.read_text()


def test_fast_menu_patches_the_front_end(game, capsys):
    front = game / "assets" / "UI" / "FrontEnd"
    front.mkdir()
    (front / "MainMenu.xml").write_text('<SlideAnim Start="60,0" AlphaStart="0"/>\n')
    main(["apply", "--game-dir", str(game), "--backup", str(game / "bak"),
          "--scale", "2", "--fast-menu"])
    assert (front / "MainMenu.xml").read_text() == (
        '<SlideAnim Start="0,0" AlphaStart="1"/>\n')
    assert "front-end animation edit" in capsys.readouterr().out


@pytest.fixture
def game_with_dlc(game):
    dlc = game / "assets" / "DLC" / "Expansion1" / "UI"
    dlc.mkdir(parents=True)
    (dlc / "Styles.xml").write_bytes(b'<Box Size="10,20"/>\n')
    return game


def test_summary_breaks_the_counts_down_per_tree(game_with_dlc, capsys):
    main(["apply", "--game-dir", str(game_with_dlc),
          "--backup", str(game_with_dlc / "bak"), "--scale", "2"])
    out = capsys.readouterr().out
    assert "2 file(s) changed" in out
    assert "base" in out and "Expansion1" in out


def test_report_file_separates_the_trees(game_with_dlc, tmp_path):
    out = tmp_path / "changes.txt"
    main(["apply", "--game-dir", str(game_with_dlc),
          "--backup", str(game_with_dlc / "bak"), "--scale", "2", "--report", str(out)])
    text = out.read_text()
    assert "[base] Styles.xml" in text
    assert "[Expansion1] Styles.xml" in text


def test_skip_tree_leaves_that_tree_stock(game_with_dlc):
    main(["apply", "--game-dir", str(game_with_dlc),
          "--backup", str(game_with_dlc / "bak"), "--scale", "2",
          "--skip-tree", "Expansion1"])
    dlc = game_with_dlc / "assets" / "DLC" / "Expansion1" / "UI" / "Styles.xml"
    assert dlc.read_bytes() == b'<Box Size="10,20"/>\n'


def test_restore_names_the_trees_it_put_back(game_with_dlc, capsys):
    main(["apply", "--game-dir", str(game_with_dlc),
          "--backup", str(game_with_dlc / "bak"), "--scale", "2"])
    main(["restore", "--game-dir", str(game_with_dlc),
          "--backup", str(game_with_dlc / "bak")])
    out = capsys.readouterr().out
    assert "base: 1 file(s)" in out
    assert "Expansion1: 1 file(s)" in out


def test_rejects_a_scale_outside_the_sane_range(game):
    with pytest.raises(SystemExit):
        main(["apply", "--game-dir", str(game), "--scale", "12"])
