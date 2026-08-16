"""The pristine backup root, and adopting the layout used before DLC trees.

Once a tree has been patched its backup is the only stock copy left, so the
migration must adopt the existing directory. Re-snapshotting would capture
patched files as "pristine" and make restore impossible -- these tests exist to
pin that down.
"""
import pytest

from civbe_uiscale import backup
from civbe_uiscale.apply import run

STOCK = b'<Box Size="100,50"/>\n'
PATCHED = b'<Box Size="200,100"/>\n'


@pytest.fixture
def game(tmp_path):
    (tmp_path / "assets" / "UI").mkdir(parents=True)
    (tmp_path / "assets" / "UI" / "Styles.xml").write_bytes(STOCK)
    return tmp_path


def legacy_backup(game, name="backup"):
    """A backup in the pre-DLC layout: the contents of Assets/UI at its root."""
    root = game / name
    root.mkdir()
    (root / "Styles.xml").write_bytes(STOCK)
    return root


def base_copy(root):
    return root / "assets" / "UI" / "Styles.xml"


class TestLayout:
    def test_a_fresh_install_needs_no_migration(self, game):
        assert backup.migrate(game / "backup", game) is False

    def test_an_empty_backup_root_needs_no_migration(self, game):
        (game / "backup").mkdir()
        assert backup.migrate(game / "backup", game) is False

    def test_a_mirrored_root_is_left_alone(self, game):
        root = game / "backup"
        (root / "assets" / "UI").mkdir(parents=True)
        assert backup.migrate(root, game) is False

    def test_refuses_a_backup_root_it_cannot_recognise(self, game):
        root = game / "backup"
        root.mkdir()
        (root / "notes.txt").write_text("what is this\n")
        with pytest.raises(ValueError, match="not a recognisable backup"):
            backup.migrate(root, game)


class TestAdoptingTheLegacyLayout:
    def test_moves_the_tree_under_its_install_relative_path(self, game):
        root = legacy_backup(game)
        assert backup.migrate(root, game) is True
        assert base_copy(root).read_bytes() == STOCK
        assert not (root / "Styles.xml").exists()

    def test_keeps_the_pristine_bytes_when_the_live_tree_is_patched(self, game):
        root = legacy_backup(game)
        (game / "assets" / "UI" / "Styles.xml").write_bytes(PATCHED)

        run(game, root, ui_scale=2.0, texture_scale=1.0)

        assert base_copy(root).read_bytes() == STOCK
        # Derived from the stock copy, not from the already-patched live file.
        assert (game / "assets" / "UI" / "Styles.xml").read_bytes() == PATCHED

    def test_finishes_a_migration_interrupted_between_the_two_renames(self, game):
        root = game / "backup"
        staging = game / "backup.migrating"
        staging.mkdir()
        (staging / "Styles.xml").write_bytes(STOCK)

        assert backup.migrate(root, game) is True
        assert base_copy(root).read_bytes() == STOCK
        assert not staging.exists()

    def test_refuses_when_both_halves_hold_a_base_tree(self, game):
        root = game / "backup"
        (root / "assets" / "UI").mkdir(parents=True)
        (root / "assets" / "UI" / "Styles.xml").write_bytes(PATCHED)
        staging = game / "backup.migrating"
        staging.mkdir()
        (staging / "Styles.xml").write_bytes(STOCK)

        with pytest.raises(ValueError, match="not pristine"):
            backup.migrate(root, game)

    def test_a_dry_run_migrates_nothing(self, game):
        root = legacy_backup(game)
        run(game, root, ui_scale=2.0, texture_scale=1.0, dry_run=True)
        assert (root / "Styles.xml").read_bytes() == STOCK
        assert not (root / "assets").exists()

    def test_a_dry_run_still_derives_from_the_legacy_copy(self, game):
        root = legacy_backup(game)
        (game / "assets" / "UI" / "Styles.xml").write_bytes(PATCHED)
        report = run(game, root, ui_scale=2.0, texture_scale=1.0, dry_run=True)
        assert report.files_changed == 1


class TestTheFastMenuStopgap:
    """An early --fast-menu kept one stock DLC file in `<backup>-dlc`."""

    @pytest.fixture
    def stopgap(self, game):
        menu = game / "assets" / "DLC" / "Expansion1" / "UI" / "FrontEnd"
        menu.mkdir(parents=True)
        (menu / "MainMenu.xml").write_bytes(PATCHED)
        held = game / "backup-dlc" / "Expansion1" / "UI" / "FrontEnd"
        held.mkdir(parents=True)
        (held / "MainMenu.xml").write_bytes(STOCK)
        return game

    def test_puts_its_file_back_before_the_tree_is_snapshotted(self, stopgap):
        root = stopgap / "backup"
        run(stopgap, root, ui_scale=2.0, texture_scale=1.0)
        pristine = (root / "assets" / "DLC" / "Expansion1" / "UI" / "FrontEnd"
                    / "MainMenu.xml")
        assert pristine.read_bytes() == STOCK

    def test_removes_itself(self, stopgap):
        run(stopgap, stopgap / "backup", ui_scale=2.0, texture_scale=1.0)
        assert not (stopgap / "backup-dlc").exists()
