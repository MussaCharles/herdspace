"""Unit tests for lib/hopen/ports.py, hopen --ports."""
import os
import pathlib
import socket
import tempfile
import unittest

import helpers  # noqa: F401  (puts lib/ on sys.path)

from hopen import ports


class PortsTest(unittest.TestCase):
    def test_the_folders_of_the_projects_come_from_the_lists(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp).resolve()
            (home / "work" / "api").mkdir(parents=True)
            (home / "work" / "herdspace.toml").write_text('[[project]]\nname = "api"\npath = "./api"\n')
            self.assertEqual(ports.project_folders(str(home)),
                             [(str(home / "work"), "work"), (str(home / "work" / "api"), "work/api")])

    def test_a_port_of_this_test_shows_with_its_project(self):
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.addCleanup(server.close)
        server.bind(("127.0.0.1", 0))
        server.listen()
        port = server.getsockname()[1]
        lines = ports.show_ports([(os.getcwd(), "work/api")])
        self.assertEqual(lines[0].split(), ["PORT", "ADDRESS", "PROGRAM", "PID", "PROJECT", "FOLDER"])
        mine = [line.split() for line in lines[1:] if line.split()[0] == str(port)]
        self.assertEqual(len(mine), 1, lines)
        self.assertEqual(mine[0][1], "127.0.0.1")
        self.assertEqual(mine[0][3], str(os.getpid()))
        self.assertEqual(mine[0][4], "work/api")


if __name__ == "__main__":
    unittest.main()
