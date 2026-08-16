"""The front-end tweaks behind --fast-menu."""
from civbe_uiscale import fastmenu

MENU = """<Context>
  <AlphaAnim ID="FirstShowDelay" Pause="0.1" AlphaStart="0" AlphaEnd="0" Cycle="Once" />
  <SlideAnim Anchor="C,T" Size="280,35" Pause=".1" Start="60,0" End="0,0" ID="SPSlide">
    <AlphaAnim Pause=".1" AlphaStart="0" AlphaEnd="1" ID="SPAlpha">
      <Grid SliceStart="4,4" Style="BaseButton"/>
    </AlphaAnim>
  </SlideAnim>
  <AlphaAnim Cycle="Bounce" AlphaStart="1" AlphaEnd="0.6" Speed="2"/>
</Context>
"""

LUA = """function OnLoad()
    if (not UI.HasShownLegal()) then
        UIManager:QueuePopup( Controls.LegalScreen, PopupPriority.LegalScreen );
    end
end
"""


class TestMainMenu:
    def test_opens_every_entry_at_full_alpha(self):
        patched, _ = fastmenu.patch_main_menu(MENU)
        assert 'AlphaStart="0"' not in patched
        assert patched.count('AlphaStart="1"') == 3

    def test_zeroes_the_slide_offset(self):
        patched, _ = fastmenu.patch_main_menu(MENU)
        assert 'Start="0,0" End="0,0"' in patched

    def test_leaves_other_start_attributes_alone(self):
        patched, _ = fastmenu.patch_main_menu(MENU)
        assert 'SliceStart="4,4"' in patched

    def test_works_at_any_scale(self):
        patched, changes = fastmenu.patch_main_menu(MENU.replace("60,0", "120,0"))
        assert 'Start="0,0" End="0,0"' in patched
        assert any(c.old == "120,0" for c in changes)

    def test_is_idempotent(self):
        once, _ = fastmenu.patch_main_menu(MENU)
        twice, changes = fastmenu.patch_main_menu(once)
        assert twice == once
        assert changes == []

    def test_reports_the_line_it_changed(self):
        _, changes = fastmenu.patch_main_menu(MENU)
        slide = [c for c in changes if c.attr == "Start"]
        assert [c.line for c in slide] == [3]


class TestFrontEndLua:
    def test_comments_out_the_legal_popup(self):
        patched, changes = fastmenu.patch_front_end_lua(LUA)
        assert "-- UIManager:QueuePopup( Controls.LegalScreen" in patched
        assert len(changes) == 1

    def test_keeps_the_indentation(self):
        patched, _ = fastmenu.patch_front_end_lua(LUA)
        assert "\n        -- UIManager" in patched

    def test_is_idempotent(self):
        once, _ = fastmenu.patch_front_end_lua(LUA)
        twice, changes = fastmenu.patch_front_end_lua(once)
        assert twice == once
        assert changes == []


class TestDispatch:
    def test_matches_the_front_end_files_case_insensitively(self):
        patched, changes = fastmenu.patch("frontend/MAINMENU.XML", MENU)
        assert changes and patched != MENU

    def test_ignores_every_other_file(self):
        patched, changes = fastmenu.patch("InGame/MainMenu.xml", MENU)
        assert (patched, changes) == (MENU, [])
