"""Check process termination without sending signals to real processes."""

import shutil
import subprocess
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("zsh"), "Requires Zsh")
class KillportTest(unittest.TestCase):
    def run_killport(self, arguments, listeners="123\\n456"):
        return subprocess.run(
            [
                "zsh",
                "-fc",
                (
                    "source packages/terminal/.config/dotfiles/zsh/functions/killport.zsh; "
                    f"lsof() {{ printf '{listeners}'; }}; "
                    "kill() { printf 'SIGNAL:%s\\n' \"$*\"; }; "
                    'killport "$@"'
                ),
                "test",
                *arguments,
            ],
            cwd=REPO,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_term_is_default_and_force_uses_kill(self):
        for arguments, signal in [(["3000"], "TERM"), (["--force", "3000"], "KILL")]:
            result = self.run_killport(arguments)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(f"SIGNAL:-s {signal} -- 123 456", result.stdout)

    def test_invalid_ports_do_not_send_signals(self):
        for arguments in [
            [],
            ["0"],
            ["65536"],
            ["abc"],
            ["-1"],
            ["3000", "4000"],
            ["--force"],
        ]:
            result = self.run_killport(arguments)
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertNotIn("SIGNAL:", result.stdout)

    def test_no_listeners_does_not_send_signals(self):
        result = self.run_killport(["3000"], listeners="")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertNotIn("SIGNAL:", result.stdout)
