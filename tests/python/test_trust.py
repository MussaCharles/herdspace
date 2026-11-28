"""Unit tests for lib/hopen/trust.py, the approval of a list."""
import contextlib
import io
import pathlib
import tempfile
import unittest

import helpers  # noqa: F401  (puts lib/ on sys.path)

from hopen import trust

RS, US = "\x1e", "\x1f"


class TrustTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = pathlib.Path(self.tmp.name)
        self.list = self.dir / "herdspace.toml"
        self.list.write_text('on_open = "echo hi"\n')
        self.state = str(self.dir / "state")

    def tearDown(self):
        self.tmp.cleanup()

    def ask(self, answer):
        self.asked = []

        def reply():
            self.asked.append(True)
            return answer + "\n"
        return reply

    def trusted(self, answer="", flag=False, extra=b""):
        with contextlib.redirect_stdout(io.StringIO()):
            return trust.list_trusted(str(self.list), "    w: run echo hi", extra, self.state, flag, self.ask(answer))

    def test_the_actions_of_each_line(self):
        items = [
            RS.join(["R", "w", "/w", "plain", "echo hi", "A=1" + US + "B=2"]),
            RS.join(["P", "api", "/w/api", "plain", "-", "-"]),
            RS.join(["T", "api", "logs", "plain", "tail -f x"]),
            RS.join(["F", "api", "/w/.env", "TOKEN=(hidden)", "TOKEN=s"]),
            RS.join(["K", "api", "test", "make test"]),
        ]
        self.assertEqual(trust.list_actions(items), [
            "    w: run echo hi",
            "    w: set A=1, B=2",
            "    api, tab logs: run tail -f x",
            "    api: load /w/.env (TOKEN=(hidden))",
            "    api, task test: run make test",
        ])

    def test_a_yes_saves_the_approval_and_asks_no_more(self):
        self.assertTrue(self.trusted("y"))
        self.assertTrue(self.trusted("n"))
        self.assertEqual(self.asked, [])

    def test_a_no_is_no(self):
        self.assertFalse(self.trusted("n"))
        self.assertFalse(self.trusted(""))

    def test_a_changed_file_asks_again(self):
        self.assertTrue(self.trusted("yes"))
        self.list.write_text('on_open = "rm -rf ~"\n')
        self.assertFalse(self.trusted("n"))
        self.assertEqual(self.asked, [True])

    def test_changed_env_file_values_ask_again(self):
        self.assertTrue(self.trusted("y", extra=b"F\x1eA=1"))
        self.assertFalse(self.trusted("n", extra=b"F\x1eA=2"))

    def test_trust_flag_approves_with_no_question(self):
        self.assertTrue(self.trusted("n", flag=True))
        self.assertTrue(self.trusted("n"))

    def test_one_line_for_each_file(self):
        self.assertTrue(self.trusted("y"))
        self.list.write_text("# changed\n")
        self.assertTrue(self.trusted("y"))
        rows = pathlib.Path(trust.trust_file(self.state)).read_text().split("\n")
        self.assertEqual(len([row for row in rows if row]), 1)

    def test_the_checksum_is_the_one_of_older_hopen(self):
        # The bash file_hash of hopen 0.16.0: sha256 of the file, then a 0 byte
        # and the env file values. A saved approval stays valid after an update.
        import hashlib
        data = self.list.read_bytes()
        self.assertEqual(trust.file_hash(str(self.list)), hashlib.sha256(data).hexdigest())
        self.assertEqual(trust.file_hash(str(self.list), b"x"), hashlib.sha256(data + b"\0x").hexdigest())


if __name__ == "__main__":
    unittest.main()
