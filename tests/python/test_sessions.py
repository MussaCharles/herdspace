"""Unit tests for lib/hopen/sessions.py and main.py, with a stub herdr that
answers like Herdr and records each call."""
import contextlib
import io
import os
import pathlib
import tempfile
import unittest
from unittest import mock

import helpers  # noqa: F401  (puts lib/ on sys.path)

from hopen import main, sessions

STUB_HERDR = """#!/bin/sh
echo "$HERDR_SESSION: $*" >>"$CALLS"
n=$(wc -l <"$CALLS" | tr -d ' ')
case "$1 $2" in
  "workspace list") echo '{"result":{"type":"workspace_list","workspaces":[]}}' ;;
  "workspace create") echo "{\\"result\\":{\\"workspace\\":{\\"workspace_id\\":\\"w$n\\"},\\"root_pane\\":{\\"pane_id\\":\\"p$n\\"}}}" ;;
  "tab create") echo "{\\"result\\":{\\"root_pane\\":{\\"pane_id\\":\\"t$n\\"}}}" ;;
  "pane split") echo "{\\"result\\":{\\"pane\\":{\\"pane_id\\":\\"s$n\\"}}}" ;;
  "pane list") echo '{"result":{"panes":[{"pane_id":"p1","tab_id":"tab1","workspace_id":"w1"}]}}' ;;
esac
"""


class SessionsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = pathlib.Path(self.tmp.name).resolve()
        stub = self.home / "bin"
        stub.mkdir()
        (stub / "herdr").write_text(STUB_HERDR)
        (stub / "herdr").chmod(0o755)
        self.calls = self.home / "calls"
        self.calls.write_text("")
        templates = self.home / "templates"
        templates.mkdir()
        (templates / "two.layout").write_text("# two: two panes\nmain - - - -\nside main right 0.4 echo side\n")
        env = {"PATH": f"{stub}:{os.environ['PATH']}", "CALLS": str(self.calls), "HOPEN_TEMPLATES": str(templates),
               "HOPEN_GUARD_SECONDS": "0", "XDG_STATE_HOME": str(self.home / "state")}
        patcher = mock.patch.dict(os.environ, env)
        patcher.start()
        self.addCleanup(patcher.stop)
        (self.home / "w" / "api").mkdir(parents=True)

    def tearDown(self):
        self.tmp.cleanup()

    def made(self):
        return [line for line in self.calls.read_text().split("\n") if line]

    def open_list(self, text, trust=True, template=""):
        path = self.home / "w" / "herdspace.toml"
        path.write_text(text)
        run = sessions.Run(str(self.home), "w", str(path), "", template, trust)
        with contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()) as err:
            run.prepare_session()
        return run, out.getvalue(), err.getvalue()

    def test_each_project_gets_a_workspace_with_its_template_and_tab(self):
        run, out, _ = self.open_list('[[project]]\nname = "api"\npath = "./api"\ntemplate = "two"\n'
                                     'on_open = "make dev"\nenv = { A = "1" }\ntabs = [{ name = "logs", run = "tail -f x" }]\n')
        made = self.made()
        self.assertIn(f"w: workspace create --cwd {self.home / 'w'} --label w --no-focus", made)
        create = next(line for line in made if "--label api" in line)
        self.assertTrue(create.endswith("--no-focus --env A=1"), create)
        self.assertTrue(any("pane run" in line and "make dev" in line for line in made))
        self.assertTrue(any(line.startswith("w: pane split ") and "--ratio 0.4" in line and line.endswith("--env A=1") for line in made))
        self.assertTrue(any("pane rename" in line and line.endswith(" side") for line in made))
        self.assertTrue(any("tab create" in line and "--label logs" in line for line in made))
        self.assertIn("Session w: 2 workspaces added.", out)
        state = (self.home / "state" / "hopen" / "w.tsv").read_text()
        self.assertIn("api\ttwo\t", state)

    def test_with_no_approval_no_command_and_no_value_runs(self):
        run, _, err = self.open_list('[[project]]\nname = "api"\npath = "./api"\non_open = "rm -rf /"\nenv = { A = "1" }\n', trust=False)
        made = self.made()
        self.assertFalse(any("rm -rf" in line for line in made))
        self.assertFalse(any("--env" in line for line in made))
        self.assertIn("hopen did not use the commands and values", err)

    def test_a_missing_folder_and_a_missing_template_warn(self):
        _, _, err = self.open_list('[[project]]\nname = "gone"\npath = "./gone"\n[[project]]\nname = "api"\npath = "./api"\ntemplate = "nope"\n')
        self.assertIn("Skipped gone: the folder", err)
        self.assertIn("api: no template named nope. It opens with one pane.", err)

    def test_the_template_note(self):
        _, out, _ = self.open_list('[[project]]\nname = "api"\npath = "./api"\n', template="two")
        self.assertNotIn("--template two split", out)

    def test_apply_needs_a_tab_with_one_pane(self):
        run = sessions.Run(str(self.home))
        with mock.patch.dict(os.environ, {"HERDR_PANE_ID": "p1"}), contextlib.redirect_stdout(io.StringIO()):
            sessions.apply_here(run, "two")
        self.assertTrue(any("pane split p1 --direction right --ratio 0.4" in line for line in self.made()))


class OptionsTest(unittest.TestCase):
    def test_the_options(self):
        o = main.parse(["work", "--template", "code", "--no-attach", "--trust", "--with-ignored", "-x/"], "dev")
        self.assertEqual((o.session, o.template, o.attach, o.trust, o.search_in), ("work", "code", False, True, ["./-x"]))
        self.assertEqual(main.parse(["--task", "test"], "dev").task, "test")
        self.assertEqual(main.parse(["--task", "--trust"], "dev").task, "")

    def test_a_bad_option_and_two_names_stop_with_2(self):
        for args in (["-x"], ["a", "b"], ["--grep"]):
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as stop:
                main.parse(args, "dev")
            self.assertEqual(stop.exception.code, 2)

    def test_version(self):
        with contextlib.redirect_stdout(io.StringIO()) as out, self.assertRaises(SystemExit):
            main.parse(["--version"], "1.2.3")
        self.assertEqual(out.getvalue(), "hopen 1.2.3\n")


if __name__ == "__main__":
    unittest.main()
