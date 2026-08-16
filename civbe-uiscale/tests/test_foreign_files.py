"""Files added to the UI tree by other tools.

A stylesheet dropped in by a previous patcher is not in the pristine backup, so
the sweep never rewrites it -- and a LanguageSpecific override silently wins
over Styles.xml. Detect and report those rather than leaving them to shadow the
result.
"""
import pytest

from civbe_uiscale.apply import run
from civbe_uiscale.cli import main


@pytest.fixture
def game(tmp_path):
    ui = tmp_path / "assets" / "UI"
    ui.mkdir(parents=True)
    (ui / "Styles.xml").write_bytes(b'<Box Size="100,50"/>\n')
    return tmp_path


def test_reports_a_file_absent_from_the_backup(game):
    backup = game / "bak"
    run(game, backup, ui_scale=2.0, texture_scale=1.0)

    intruder = game / "assets" / "UI" / "LanguageSpecific" / "en_US"
    intruder.mkdir(parents=True)
    (intruder / "LanguageSpecificStyles.xml").write_bytes(b"<StyleSheet/>\n")

    report = run(game, backup, ui_scale=3.0, texture_scale=1.0)
    assert [str(p).replace("\\", "/") for p in report.foreign_files] == [
        "LanguageSpecific/en_US/LanguageSpecificStyles.xml"
    ]


def test_no_foreign_files_on_a_clean_tree(game):
    report = run(game, game / "bak", ui_scale=2.0, texture_scale=1.0)
    assert report.foreign_files == []


def test_cli_warns_about_them(game, capsys):
    backup = game / "bak"
    main(["apply", "--game-dir", str(game), "--backup", str(backup), "--scale", "2"])
    intruder = game / "assets" / "UI" / "LanguageSpecific" / "en_US"
    intruder.mkdir(parents=True)
    (intruder / "LanguageSpecificStyles.xml").write_bytes(b"<StyleSheet/>\n")

    main(["apply", "--game-dir", str(game), "--backup", str(backup), "--scale", "2"])
    out = capsys.readouterr().out
    assert "not in the pristine backup" in out
    assert "LanguageSpecificStyles.xml" in out
