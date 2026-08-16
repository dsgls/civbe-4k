"""The command line: info, decode, encode."""
import struct

from civbe_dds.cli import main
from civbe_dds.encode import write
from civbe_dds.header import DDS_MAGIC, HEADER_LEN, header
from civbe_dds.image import Image
from civbe_dds.png import read_png, write_png


def _image(width=2, height=2, rgba=None, group=""):
    if rgba is None:
        rgba = bytes((i * 13 + 5) % 256 for i in range(width * height * 4))
    return Image(width=width, height=height, rgba=rgba, group=group)


def _dds(tmp_path, name, **kw):
    p = tmp_path / ("%s.dds" % name)
    write(str(p), _image(**{k: v for k, v in kw.items() if k != "group"}),
          group=kw.get("group"))
    return p


def _png(tmp_path, name, **kw):
    p = tmp_path / ("%s.png" % name)
    write_png(str(p), _image(**kw))
    return p


def _raw_header(width, height, *, mips=1, bits=32, rmask=0xff, pfflags=0x40):
    """A hand-built 128-byte header with a declared mip count and no FTXT --
    used only to control `mips` and pixel-data length for the info size
    check, which build_header (always mips=1, exact-fit pixels) can't
    exercise."""
    d = bytearray(HEADER_LEN)
    d[0:4] = DDS_MAGIC
    struct.pack_into("<I", d, 4, 124)
    struct.pack_into("<I", d, 8, pfflags)
    struct.pack_into("<II", d, 12, height, width)
    struct.pack_into("<I", d, 28, mips)
    struct.pack_into("<I", d, 80, pfflags)
    struct.pack_into("<I", d, 88, bits)
    struct.pack_into("<I", d, 92, rmask)
    return bytes(d)


class TestInfo:
    def test_prints_dims_format_tag_group_mips_and_plain(self, tmp_path, capsys):
        p = _dds(tmp_path, "t", width=4, height=2, group="Interface Scalable")
        assert main(["info", str(p)]) == 0
        out = capsys.readouterr().out
        assert "4x2" in out
        assert "A8B8G8R8" in out
        assert "COLOR" in out
        assert "Interface Scalable" in out
        assert "mips=1" in out
        assert "plain" in out

    def test_reports_pair_for_a_dictionary_with_an_index_sibling(self, tmp_path, capsys):
        dic = _dds(tmp_path, "atlas")
        (tmp_path / "atlas-index.dds").write_bytes(b"\0")
        assert main(["info", str(dic)]) == 0
        assert "pair" in capsys.readouterr().out

    def test_non_dds_file_fails_but_does_not_raise(self, tmp_path, capsys):
        bad = tmp_path / "bad.dds"
        bad.write_bytes(b"not a dds")
        code = main(["info", str(bad)])
        assert code == 1
        assert str(bad) in capsys.readouterr().err

    def test_file_exactly_matching_level_0_size_has_no_warning(self, tmp_path, capsys):
        # 2x1 32-bit -> 8 bytes of level-0 pixel data, present in full.
        raw = _raw_header(2, 1) + bytes(8)
        p = tmp_path / "t.dds"
        p.write_bytes(raw)
        assert main(["info", str(p)]) == 0
        assert capsys.readouterr().err == ""

    def test_file_carrying_a_real_trailing_mip_is_not_a_false_positive(self, tmp_path, capsys):
        # This is the case the design spec calls out: comparing against
        # level-0 alone must NOT flag a file that legitimately carries more
        # data than level 0 (a trailing mip level here).
        raw = _raw_header(2, 1, mips=2) + bytes(8) + bytes(4)  # level0 + level1
        p = tmp_path / "t.dds"
        p.write_bytes(raw)
        assert main(["info", str(p)]) == 0
        assert capsys.readouterr().err == ""

    def test_file_shorter_than_level_0_fails_with_a_warning(self, tmp_path, capsys):
        # 2x1 32-bit needs 8 bytes; only 4 are present.
        raw = _raw_header(2, 1) + bytes(4)
        p = tmp_path / "t.dds"
        p.write_bytes(raw)
        code = main(["info", str(p)])
        assert code == 1
        err = capsys.readouterr().err
        assert str(p) in err
        assert "shorter" in err.lower()


class TestDecode:
    def test_decodes_to_a_png_alongside_the_input(self, tmp_path, capsys):
        p = _dds(tmp_path, "t", width=3, height=2)
        assert main(["decode", str(p)]) == 0
        out = tmp_path / "t.png"
        assert out.exists()
        img = read_png(str(out))
        assert (img.width, img.height) == (3, 2)

    def test_dash_o_writes_into_the_given_directory(self, tmp_path, capsys):
        p = _dds(tmp_path, "t")
        out_dir = tmp_path / "out"
        assert main(["decode", str(p), "-o", str(out_dir)]) == 0
        assert (out_dir / "t.png").exists()
        assert not (tmp_path / "t.png").exists()

    def test_continues_past_a_bad_file_and_exits_1(self, tmp_path, capsys):
        good1 = _dds(tmp_path, "good1")
        bad = tmp_path / "bad.dds"
        bad.write_bytes(b"not a dds")
        good2 = _dds(tmp_path, "good2")

        code = main(["decode", str(good1), str(bad), str(good2)])

        assert code == 1
        assert (tmp_path / "good1.png").exists()
        assert (tmp_path / "good2.png").exists()  # processing continued past `bad`
        assert not (tmp_path / "bad.png").exists()
        assert str(bad) in capsys.readouterr().err


class TestEncode:
    def test_encodes_to_a_dds_with_the_default_group(self, tmp_path, capsys):
        p = _png(tmp_path, "t", width=3, height=2)
        assert main(["encode", str(p)]) == 0
        out = tmp_path / "t.dds"
        assert out.exists()
        assert header(str(out)).group == "Interface"

    def test_dash_o_writes_into_the_given_directory(self, tmp_path, capsys):
        p = _png(tmp_path, "t")
        out_dir = tmp_path / "out"
        assert main(["encode", str(p), "-o", str(out_dir)]) == 0
        assert (out_dir / "t.dds").exists()
        assert not (tmp_path / "t.dds").exists()

    def test_group_flag_sets_the_usage_name_literally(self, tmp_path):
        p = _png(tmp_path, "t")
        main(["encode", str(p), "--group", "Interface Scalable"])
        assert header(str(tmp_path / "t.dds")).group == "Interface Scalable"

    def test_like_flag_carries_the_stock_files_group_not_the_default(self, tmp_path):
        # The stock file's group ("Interface Scalable") differs from the
        # tool's own default ("Interface"); only --like's actual application
        # of it, not a coincidental match, makes this pass.
        stock = _dds(tmp_path, "stock", group="Interface Scalable")
        p = _png(tmp_path, "t")
        main(["encode", str(p), "--like", str(stock)])
        assert header(str(tmp_path / "t.dds")).group == "Interface Scalable"

    def test_like_and_group_are_mutually_exclusive(self, tmp_path):
        stock = _dds(tmp_path, "stock", group="Interface Scalable")
        p = _png(tmp_path, "t")
        try:
            main(["encode", str(p), "--like", str(stock), "--group", "X"])
            assert False, "expected argparse to reject --like with --group"
        except SystemExit as exc:
            assert exc.code != 0

    def test_continues_past_a_bad_file_and_exits_1(self, tmp_path, capsys):
        good1 = _png(tmp_path, "good1")
        bad = tmp_path / "bad.png"
        bad.write_bytes(b"not a png")
        good2 = _png(tmp_path, "good2")

        code = main(["encode", str(good1), str(bad), str(good2)])

        assert code == 1
        assert (tmp_path / "good1.dds").exists()
        assert (tmp_path / "good2.dds").exists()  # processing continued past `bad`
        assert not (tmp_path / "bad.dds").exists()
        assert str(bad) in capsys.readouterr().err
