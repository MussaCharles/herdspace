"""Unit tests for lib/hopen/templates.py."""
import os
import pathlib
import stat
import tempfile
import unittest

import helpers  # noqa: F401  (puts lib/ on sys.path)

from hopen import templates

STUB_HERDR = """#!/bin/sh
# A stub herdr: one pane with the label "auto", in one tab with the label "auto".
case "$1 $2" in
  "pane list") echo '{"result":{"panes":[{"pane_id":"p1","label":"auto","workspace_id":"w1","tab_id":"t1"}]}}' ;;
  "tab list") echo '{"result":{"tabs":[{"tab_id":"t1","label":"auto"}]}}' ;;
  *) echo "$@" >>"$CALLS" ;;
esac
"""


class TemplatesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = pathlib.Path(self.tmp.name)
        (self.dir / "code.layout").write_text("# code: Neovim and an agent.\n# NAME FROM\n\neditor - - - nvim .\n  agent editor right 0.5 -\n")

    def tearDown(self):
        self.tmp.cleanup()

    def test_plain_always_exists(self):
        self.assertTrue(templates.template_exists(str(self.dir), "plain"))

    def test_a_name_cannot_leave_the_folder(self):
        (self.dir.parent / "x.layout").write_text("a - - - b\n")
        self.addCleanup((self.dir.parent / "x.layout").unlink)
        self.assertFalse(templates.template_exists(str(self.dir), "../x"))
        self.assertTrue(templates.template_exists(str(self.dir), "code"))
        self.assertFalse(templates.template_exists(str(self.dir), "missing"))

    def test_the_lines_leave_out_comments_and_empty_lines(self):
        self.assertEqual(templates.template_lines(str(self.dir), "code"),
                         ["editor - - - nvim .", "  agent editor right 0.5 -"])

    def test_the_table_has_plain_and_each_description(self):
        lines = templates.show_templates(str(self.dir))
        self.assertEqual(lines[0].split(), ["TEMPLATE", "DESCRIPTION"])
        self.assertTrue(lines[1].startswith("plain        One pane"))
        self.assertEqual(lines[2], "code         Neovim and an agent.")

    def test_the_guard_puts_back_a_changed_name(self):
        stub = self.dir / "herdr"
        stub.write_text(STUB_HERDR)
        stub.chmod(stub.stat().st_mode | stat.S_IEXEC)
        calls = self.dir / "calls"
        old = dict(os.environ)
        self.addCleanup(os.environ.update, old)
        os.environ["PATH"] = f"{self.dir}:{os.environ['PATH']}"
        os.environ["CALLS"] = str(calls)
        templates.guard("p1\teditor\n\x1ep1\tapi\n", "0.8")
        made = calls.read_text().split("\n")
        self.assertIn("pane rename p1 editor", made)
        self.assertIn("tab rename t1 api", made)


if __name__ == "__main__":
    unittest.main()
