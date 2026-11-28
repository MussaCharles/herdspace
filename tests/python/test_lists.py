"""Unit tests for lib/hopen/lists.py, the reader of the project lists.

Each test writes a list in a temporary folder, reads it with read_list or
find_lists, and checks the result. Some tests run the package as bin/hopen
does. They need only the standard library, and no Herdr. Run them with:

    python3 -B -m unittest discover -s tests/python
"""
import os
import pathlib
import tempfile
import unittest

from helpers import run

from hopen import lists

RS = "\x1e"
US = "\x1f"


def read(path, what="items", template=""):
    """Read a list, and return its lines split into fields."""
    return [line.split(RS) for line in lists.read_list(str(path), what, template)]


class ListReaderTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name).resolve() / "work"
        (self.root / "api").mkdir(parents=True)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, name, text):
        path = self.root / name
        path.write_text(text)
        return path

    def toml(self):
        return self.write("herdspace.toml", "\n".join([
            'session = "work"',
            'template = "code"',
            'on_open = "echo hi"',
            "[env]",
            'A = "1"',
            "[[project]]",
            'name = "api"',
            'path = "./api"',
            "[[project.tabs]]",
            'name = "logs"',
            'run = "tail -f log"',
            "[project.tasks]",
            'test = "make test"',
            "",
        ]))

    def test_toml_session(self):
        self.assertEqual(read(self.toml(), "session"), [["work"]])

    def test_toml_items(self):
        lines = read(self.toml())
        self.assertEqual(lines[0], ["R", "work", str(self.root), "code", "echo hi", "A=1"])
        self.assertIn(["P", "api", str(self.root / "api"), "code", "-", "-"], lines)
        self.assertIn(["K", "api", "test", "make test"], lines)
        self.assertIn(["T", "api", "logs", "plain", "tail -f log"], lines)

    def test_env_values_use_the_unit_separator(self):
        path = self.write("herdspace.toml", '[env]\nA = "1"\nB = "2"\n[[project]]\nname = "api"\npath = "./api"\n')
        env = read(path)[0][5]
        self.assertEqual(sorted(env.split(US)), ["A=1", "B=2"])

    def test_a_template_name_with_a_path_is_refused(self):
        path = self.write("herdspace.toml", 'template = "code"\n[[project]]\nname = "api"\npath = "./api"\ntemplate = "../../x"\n')
        lines = read(path)
        self.assertTrue(any(f[0] == "W" and "../../x" in f[1] for f in lines))
        self.assertIn(["P", "api", str(self.root / "api"), "code", "-", "-"], lines)

    def test_the_template_option_wins(self):
        lines = read(self.toml(), template="grid")
        self.assertEqual({f[3] for f in lines if f[0] in ("R", "P")}, {"grid"})

    def test_vscode_file_with_comments_and_trailing_commas(self):
        path = self.write("w.code-workspace", "\n".join([
            "{",
            "  // a comment",
            '  "folders": [ { "name": "web", "path": "./api" }, ],',
            '  "settings": { "hopen.session": "vs" },',
            "}",
        ]))
        self.assertEqual(read(path, "session"), [["vs"]])
        self.assertIn(["P", "web", str(self.root / "api"), "plain", "-", "-"], read(path))

    def test_a_control_character_is_shown_as_a_question_mark(self):
        path = self.write("w.code-workspace", '{"folders": [{"name": "web\\u001b[31m", "path": "./api"}]}')
        names = [f[1] for f in read(path) if f[0] == "P"]
        self.assertEqual(names, ["web?[31m"])
        for fields in read(path):
            for value in fields:
                self.assertNotIn("\x1b", value)

    def test_an_empty_field_is_a_dash(self):
        path = self.write("herdspace.toml", '[[project]]\nname = "api"\npath = "./api"\n')
        parent = read(path)[0]
        self.assertEqual(parent[0], "R")
        self.assertEqual(parent[4:], ["-", "-"])

    def test_a_broken_file_raises_list_error(self):
        path = self.write("herdspace.toml", "not = [toml")
        with self.assertRaises(lists.ListError):
            read(path)

    def test_the_package_prints_the_lines_as_bash_reads_them(self):
        result = run("internal", "read-list", str(self.toml()), "items", "")
        self.assertEqual(result.returncode, 0)
        # Split at new lines only: splitlines() also splits at the byte 0x1e.
        first = result.stdout.split("\n")[0].split(RS)
        self.assertEqual(first[:2], ["R", "work"])

    def test_the_package_reports_a_broken_list(self):
        path = self.write("herdspace.toml", "not = [toml")
        result = run("internal", "read-list", str(path), "items", "")
        self.assertEqual(result.returncode, 1)
        self.assertIn("herdspace.toml", result.stderr)


class FindListsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = pathlib.Path(self.tmp.name).resolve()

    def tearDown(self):
        self.tmp.cleanup()

    def toml(self, folder, text='[[project]]\nname = "a"\npath = "."\n'):
        (self.home / folder).mkdir(exist_ok=True)
        path = self.home / folder / "herdspace.toml"
        path.write_text(text)
        return str(path)

    def vscode(self, folder, session=None):
        (self.home / folder).mkdir(exist_ok=True)
        path = self.home / folder / f"{folder}.code-workspace"
        settings = f', "settings": {{"hopen.session": "{session}"}}' if session else ""
        path.write_text('{"folders": [{"path": "."}]' + settings + "}")
        return str(path)

    def test_each_list_has_its_session(self):
        a = self.toml("alpha")
        b = self.vscode("beta")
        found, warnings = lists.find_lists(str(self.home))
        self.assertEqual(found, [("alpha", a), ("beta", b)])
        self.assertEqual(warnings, [])

    def test_a_claimed_name_never_takes_over_an_own_name(self):
        own = self.toml("alpha")
        claim = self.toml("other", 'session = "alpha"\n[[project]]\nname = "c"\npath = "."\n')
        found, warnings = lists.find_lists(str(self.home))
        self.assertEqual(found, [("alpha", own)])
        self.assertEqual(warnings, [f"  [warn] {claim} claims the session alpha, which {own} has. hopen skips it."])

    def test_two_claims_of_one_name_skip_both(self):
        one = self.vscode("one", "shared")
        two = self.vscode("two", "shared")
        found, warnings = lists.find_lists(str(self.home))
        self.assertEqual(found, [])
        self.assertEqual(warnings[0], "  [warn] Two lists claim the session shared. hopen skips both. Give one another name:")
        self.assertEqual(sorted(warnings[1:]), sorted([f"         {one}", f"         {two}"]))

    def test_herdspace_toml_wins_over_a_vscode_file_of_the_same_name(self):
        toml = self.toml("x")
        (self.home / "x.code-workspace").write_text('{"folders": [{"path": "."}]}')
        found, warnings = lists.find_lists(str(self.home))
        self.assertEqual(found, [("x", toml)])
        self.assertEqual(warnings, [f"  [warn] Session x has two lists. hopen uses {toml}."])

    def test_a_broken_list_is_skipped_with_a_warning(self):
        bad = self.toml("bad", "not = [toml")
        found, warnings = lists.find_lists(str(self.home))
        self.assertEqual(found, [])
        self.assertTrue(warnings[0].startswith(f"  [warn] Skipped {bad}. "))

    def test_a_session_that_is_not_a_valid_name_is_skipped(self):
        self.vscode("odd", "bad name")
        self.assertEqual(lists.find_lists(str(self.home)), ([], []))


if __name__ == "__main__":
    unittest.main()
