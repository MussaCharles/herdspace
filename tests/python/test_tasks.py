"""Unit tests for lib/hopen/tasks.py, hopen --task."""
import os
import pathlib
import stat
import tempfile
import unittest

from helpers import run

from hopen import lists, tasks

RS, US = "\x1e", "\x1f"
LIST = ('{ "folders": [ { "name": "api", "path": "./api" } ], "settings": {'
        ' "hopen.tasks": { "api": { "test": "echo ran-$HB_T; exit 3" }, "tw": { "all": "echo parent" } },'
        ' "hopen.env": { "api": { "HB_T": "with-env" } } } }')
STUB_HERDR = """#!/bin/sh
echo "$@" >>"$CALLS"
case "$1 $2" in
  "pane split") echo '{"result":{"pane":{"pane_id":"p9"}}}' ;;
  "pane list") echo '{"result":{"panes":[{"pane_id":"p9","label":"test"}]}}' ;;
esac
"""


class TasksTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = pathlib.Path(self.tmp.name).resolve()
        (self.home / "tw" / "api").mkdir(parents=True)
        (self.home / "tw" / "tw.code-workspace").write_text(LIST)
        self.list = str(self.home / "tw" / "tw.code-workspace")

    def tearDown(self):
        self.tmp.cleanup()

    def task(self, folder, *args, **extra):
        env = {"HOME": str(self.home), "PATH": os.environ["PATH"], "PWD": str(folder), "SHELL": "/bin/sh", **extra}
        return run("internal", "task", *args, env=env)

    def test_the_deepest_project_wins(self):
        self.assertEqual(tasks.project_for_dir(str(self.home), str(self.home / "tw" / "api" / "src")), (self.list, "api"))
        self.assertEqual(tasks.project_for_dir(str(self.home), str(self.home / "tw")), (self.list, "tw"))
        self.assertIsNone(tasks.project_for_dir(str(self.home), str(self.home)))

    def test_env_values_win_over_the_env_file(self):
        items = [RS.join(["F", "api", "/x/.env", "A=1, C=3", "A=1" + US + "C=3"]),
                 RS.join(["P", "api", "/x", "plain", "-", "A=2" + US + "B=2"])]
        self.assertEqual(tasks.env_for(items, "api"), ["A=2", "B=2", "C=3"])
        self.assertEqual(tasks.env_for(items, "other"), [])

    def test_with_no_name_and_no_terminal_it_prints_the_tasks(self):
        result = self.task(self.home / "tw" / "api", "", "0", str(self.home / "state"))
        self.assertEqual(result.stdout, "test\techo ran-$HB_T; exit 3\n")

    def test_a_task_needs_an_approved_list(self):
        result = self.task(self.home / "tw" / "api", "test", "0", str(self.home / "state"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("only from an approved list", result.stderr)

    def test_a_task_runs_here_with_the_env_values_and_its_exit_status(self):
        result = self.task(self.home / "tw" / "api", "test", "1", str(self.home / "state"))
        self.assertEqual(result.returncode, 3)
        self.assertIn("ran-with-env", result.stdout)

    def test_an_unknown_task_names_the_tasks(self):
        result = self.task(self.home / "tw" / "api", "nope", "1", str(self.home / "state"))
        self.assertIn("The project api has no task nope. Its tasks: test", result.stderr)

    def test_in_herdr_a_task_runs_in_a_new_pane(self):
        stub = self.home / "bin"
        stub.mkdir()
        (stub / "herdr").write_text(STUB_HERDR)
        (stub / "herdr").chmod(0o755)
        calls = self.home / "calls"
        env = {"PATH": f"{stub}:{os.environ['PATH']}", "HERDR_PANE_ID": "p1", "CALLS": str(calls)}
        result = self.task(self.home / "tw" / "api", "test", "1", str(self.home / "state"), **env)
        self.assertEqual(result.returncode, 0, result.stderr)
        made = calls.read_text().split("\n")
        self.assertEqual(made[0], "pane split p1 --direction down --ratio 0.65 --focus --env HB_T=with-env")
        self.assertIn("pane rename p9 test", made)
        self.assertTrue(any(line.startswith("pane run p9 cd ") and line.endswith("&& echo ran-$HB_T; exit 3") for line in made))
        self.assertIn("Task test runs in a new pane", result.stdout)


if __name__ == "__main__":
    unittest.main()
