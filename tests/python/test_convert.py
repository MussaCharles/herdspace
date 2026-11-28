"""Unit tests for lib/hopen/convert.py, hopen --convert."""
import io
import pathlib
import tempfile
import tomllib
import unittest
from contextlib import redirect_stderr

import helpers  # noqa: F401  (puts lib/ on sys.path)

from hopen import convert, lists

VSCODE = """{
  // a comment
  "folders": [ {"name": "api", "path": "./api"}, ],
  "settings": {
    "hopen.templates": {"api": "grid"},
    "hopen.onOpen": {"api": "make \\"dev\\"", "w": "echo top"},
    "hopen.tabs": {"api": [{"name": "logs", "run": "tail -f x"}]},
    "hopen.env": {"api": {"A": "1"}},
    "hopen.tasks": {"api": {"test": "make test"}}
  }
}
"""


class ConvertTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = str(pathlib.Path(self.tmp.name).resolve())
        self.folder = pathlib.Path(self.home) / "w"
        (self.folder / "api").mkdir(parents=True)
        (self.folder / "w.code-workspace").write_text(VSCODE)

    def tearDown(self):
        self.tmp.cleanup()

    def test_the_new_file_has_the_same_projects_and_settings(self):
        target, source = convert.convert_list("w", self.home)
        self.assertEqual(source, str(self.folder / "w.code-workspace"))
        data = tomllib.loads(pathlib.Path(target).read_text())
        self.assertEqual(data["on_open"], "echo top")
        project = data["project"][0]
        self.assertEqual(project["name"], "api")
        self.assertEqual(project["path"], "api")
        self.assertEqual(project["template"], "grid")
        self.assertEqual(project["on_open"], 'make "dev"')
        self.assertEqual(project["env"], {"A": "1"})
        self.assertEqual(project["tasks"], {"test": "make test"})
        self.assertEqual(project["tabs"], [{"name": "logs", "template": "plain", "run": "tail -f x"}])

    def test_hopen_reads_the_new_file_as_the_old_one(self):
        old = lists.read_list(str(self.folder / "w.code-workspace"), "items")
        target, _ = convert.convert_list("w", self.home)
        self.assertEqual(lists.read_list(target, "items"), old)

    def test_it_never_replaces_a_file(self):
        (self.folder / "herdspace.toml").write_text("# mine\n")
        with redirect_stderr(io.StringIO()) as err, self.assertRaises(SystemExit):
            convert.convert_list("w", self.home)
        self.assertIn("exists", err.getvalue())
        self.assertEqual((self.folder / "herdspace.toml").read_text(), "# mine\n")

    def test_a_name_with_no_vscode_list_stops(self):
        with redirect_stderr(io.StringIO()) as err, self.assertRaises(SystemExit):
            convert.convert_list("nope", self.home)
        self.assertIn("No VS Code list for nope.", err.getvalue())

    def test_no_list_of_projects_writes_parent_workspace_false(self):
        text = convert.toml_text("/h/p/p.code-workspace", "/h/p/herdspace.toml", "/h", [])
        self.assertIn("parent_workspace = false", text)


if __name__ == "__main__":
    unittest.main()
