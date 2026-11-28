"""Unit tests for lib/hopen/panes.py, editor.py, and quickopen.py, with a stub herdr."""
import os
import pathlib
import tempfile
import unittest
from unittest import mock

from helpers import run

from hopen import editor, panes, quickopen

STUB_HERDR = """#!/bin/sh
echo "$@" >>"$CALLS"
case "$1 $2" in
  "pane process-info") case "$4" in
      vim*) echo '{"result":{"process_info":{"foreground_processes":[{"name":"nvim"}]}}}' ;;
      sh*) echo '{"result":{"process_info":{"foreground_processes":[{"name":"zsh"}]}}}' ;;
      *) echo '{"result":{"process_info":{"foreground_processes":[{"name":"lazygit"}]}}}' ;;
    esac ;;
  "pane list") echo '{"result":{"panes":[{"pane_id":"git1","tab_id":"t1"},{"pane_id":"vim2","tab_id":"t1"}]}}' ;;
  "pane layout") echo '{"result":{"layout":{"focused_pane_id":"vim2","panes":[]}}}' ;;
  "pane split") echo '{"result":{"pane":{"pane_id":"new1"}}}' ;;
  "tab create") echo '{"result":{"root_pane":{"pane_id":"new2"}}}' ;;
  "pane read") echo '%' ;;
esac
"""


class PanesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = pathlib.Path(self.tmp.name)
        (self.dir / "herdr").write_text(STUB_HERDR)
        (self.dir / "herdr").chmod(0o755)
        self.calls = self.dir / "calls"
        patcher = mock.patch.dict(os.environ, {"PATH": f"{self.dir}:{os.environ['PATH']}", "CALLS": str(self.calls)})
        patcher.start()
        self.addCleanup(patcher.stop)

    def tearDown(self):
        self.tmp.cleanup()

    def made(self):
        return self.calls.read_text().split("\n") if self.calls.exists() else []

    def test_a_file_goes_to_the_neovim_of_the_focused_pane(self):
        panes.open_target(panes.Place("vim1", "w1", "t1"), "/p/it's.md", "/p", "12", "/h")
        self.assertIn("pane send-text vim1 :execute 'drop' fnameescape('/p/it''s.md') | call cursor(12, 1)", self.made())

    def test_a_shell_at_its_prompt_starts_the_editor(self):
        with mock.patch.dict(os.environ, {"EDITOR": "nvim"}):
            panes.open_target(panes.Place("sh1", "w1", "t1"), "/p/a b.md", "/p", "x9", "/h")
        self.assertIn("pane run sh1 nvim '/p/a b.md'", self.made())

    def test_else_the_neovim_pane_of_the_tab(self):
        panes.open_target(panes.Place("git1", "w1", "t1"), "/p/a.md", "/p", "", "/h")
        self.assertIn("pane send-text vim2 :execute 'drop' fnameescape('/p/a.md')", self.made())

    def test_a_chosen_place_opens_a_new_editor_there(self):
        with mock.patch.dict(os.environ, {"EDITOR": "vi"}):
            panes.open_target(panes.Place("vim1", "w1", "t1", "down"), "/p/a.md", "/p", "3", "/h")
        made = self.made()
        self.assertIn("pane split --pane vim1 --direction down --cwd /p --focus", made)
        self.assertIn("pane run new1 exec env vi +3 /p/a.md", made)

    def test_a_tab_with_a_command(self):
        panes.run_at(panes.Place("p1", "w1", "t1", "tab"), "here", "git", "/p", "lazygit")
        self.assertEqual(self.made()[:2], ["tab create --workspace w1 --cwd /p --label git --focus", "pane read new2"])
        self.assertIn("pane run new2 lazygit", self.made())

    def test_the_focus_steps_toward_the_pane(self):
        layout = {"focused_pane_id": "a", "panes": [
            {"pane_id": "a", "rect": {"x": 0, "y": 0, "width": 10, "height": 10}},
            {"pane_id": "b", "rect": {"x": 10, "y": 0, "width": 10, "height": 10}},
            {"pane_id": "c", "rect": {"x": 0, "y": 10, "width": 10, "height": 10}}]}
        self.assertEqual(panes.focus_step(layout, "b"), ("right", "a"))
        self.assertEqual(panes.focus_step(layout, "c"), ("down", "a"))
        self.assertIsNone(panes.focus_step(layout, "a"))

    def test_a_line_is_digits_only(self):
        self.assertEqual(panes.digits("42"), "42")
        self.assertEqual(panes.digits("4$(x)"), "")


class EditorTest(unittest.TestCase):
    def test_the_herdspace_neovim_with_no_own_neovim_files(self):
        with tempfile.TemporaryDirectory() as home:
            (pathlib.Path(home) / ".config" / "herdspace-nvim").mkdir(parents=True)
            with mock.patch.dict(os.environ, {"EDITOR": "", "NVIM_APPNAME": ""}):
                self.assertEqual(editor.editor_command(home), "NVIM_APPNAME=herdspace-nvim nvim")
                (pathlib.Path(home) / ".config" / "nvim").mkdir()
                self.assertEqual(editor.editor_command(home), "nvim")
            with mock.patch.dict(os.environ, {"EDITOR": "hx"}):
                self.assertEqual(editor.editor_command(home), "hx")

    def test_run_at_here_runs_the_command_in_the_folder(self):
        with tempfile.TemporaryDirectory() as folder:
            result = run("internal", "run-at", "", "", "", "", "here", "x", folder, "pwd -P",
                         env={"PATH": os.environ["PATH"], "HOME": folder})
            self.assertEqual(result.stdout.strip(), os.path.realpath(folder))

    def test_a_name_that_starts_with_a_dash_is_never_an_option(self):
        with mock.patch("os.execvp") as start, mock.patch.dict(os.environ, {"VISUAL": "", "EDITOR": "vim -p"}):
            editor.open_in_editor("-x.md", "7")
        start.assert_called_once_with("vim", ["vim", "-p", "+7", "./-x.md"])

    def test_vscode_takes_the_line_with_goto(self):
        with mock.patch("os.execvp") as start, mock.patch.dict(os.environ, {"VISUAL": "code --wait"}):
            editor.open_in_editor("a.py", "3")
        start.assert_called_once_with("code", ["code", "--wait", "--goto", "a.py:3"])


class QuickOpenTest(unittest.TestCase):
    def test_the_menu_shows_no_dot_slash_except_before_a_dash(self):
        self.assertEqual(quickopen.file_line("./src/a.py"), "src/a.py")
        self.assertEqual(quickopen.file_line("./-x/d.txt"), "./-x/d.txt")


if __name__ == "__main__":
    unittest.main()
