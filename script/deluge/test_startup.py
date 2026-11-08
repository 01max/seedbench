"""Verify that a slowly starting daemon still completes the isolated protocol."""

import contextlib
import io
import json
import subprocess
import sys
import unittest
from unittest.mock import patch

import verify


class DaemonStartupTest(unittest.TestCase):
    def test_slow_daemon_completes_protocol(self):
        start_process = subprocess.Popen

        def delayed_daemon(arguments, *args, **kwargs):
            if arguments[0] == "deluged":
                arguments = [sys.executable, "-c",
                             "import os, sys, time; time.sleep(3); "
                             "os.execvp(sys.argv[1], sys.argv[1:])", *arguments]
            return start_process(arguments, *args, **kwargs)

        output = io.StringIO()
        with patch("verify.subprocess.Popen", side_effect=delayed_daemon):
            with contextlib.redirect_stdout(output):
                verify.main()

        report = json.loads(output.getvalue())
        self.assertTrue(report["fixture_torrents_removed"])
        self.assertTrue(report["global_configuration_preserved"])
        self.assertTrue(report["payload_hashes_preserved"])


if __name__ == "__main__":
    unittest.main()
