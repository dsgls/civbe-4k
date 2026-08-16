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


def test_rejects_a_scale_outside_the_sane_range(game):
    with pytest.raises(SystemExit):
        main(["apply", "--game-dir", str(game), "--scale", "12"])
