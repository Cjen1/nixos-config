#!/usr/bin/env python3
"""Exercise managed launcher patching without starting copilotd."""

import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest


PATCHER = Path(os.environ.get(
    "startupPatcher",
    str(Path(__file__).resolve().parents[1] / "hosts/msft/patch-copilotd-startup.py"),
))


class StartupTests(unittest.TestCase):
    def test_patch_and_run(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            environment = root / "managed env.sh"
            environment.write_text(
                "msft_copilotd_environment_name() {\n"
                "case \"$1\" in actual-codespace) printf '%s\\n' cs3 ;; "
                "*) printf '%s\\n' \"$1\" ;; esac\n}\n"
            )
            launcher = root / "start.sh"
            for existing_patch in (False, True):
                for late_identity in (False, True):
                    with self.subTest(existing_patch=existing_patch, late_identity=late_identity):
                        source = "#!/bin/bash\nset -euo pipefail\n"
                        if existing_patch:
                            quoted = shlex.quote(str(environment))
                            source += (
                                "# nixos-config: managed copilotd environment\n"
                                f"if [ -r {quoted} ]; then\n  . {quoted}\nfi\n"
                            )
                        if late_identity:
                            source += "export CODESPACE_NAME=actual-codespace\n"
                        source += (
                            "printf '%s\\n' --environment-name \"$CODESPACE_NAME\"\n"
                            "printf 'identity=%s\\n' \"$CODESPACE_NAME\"\n"
                        )
                        launcher.write_text(source)
                        launcher.chmod(0o750)
                        patched = None
                        for _ in range(2):
                            result = subprocess.run(
                                [sys.executable, str(PATCHER), str(launcher), str(environment)],
                                capture_output=True, text=True,
                            )
                            self.assertEqual(result.returncode, 0, result.stderr)
                            if patched is not None:
                                self.assertEqual(launcher.read_bytes(), patched)
                            patched = launcher.read_bytes()
                            self.assertEqual(launcher.stat().st_mode & 0o777, 0o750)
                        env = dict(os.environ, CODESPACE_NAME="actual-codespace")
                        if late_identity:
                            env.pop("CODESPACE_NAME")
                        output = subprocess.check_output(["bash", str(launcher)], env=env, text=True)
                        self.assertEqual(output.splitlines(), [
                            "--environment-name", "cs3", "identity=actual-codespace",
                        ])
                        if not late_identity:
                            env["CODESPACE_NAME"] = "unregistered"
                            output = subprocess.check_output(["bash", str(launcher)], env=env, text=True)
                            self.assertIn("unregistered\nidentity=unregistered\n", output)

    def test_reject_unexpected_launcher_without_writing(self):
        with tempfile.TemporaryDirectory() as temporary:
            launcher = Path(temporary) / "start.sh"
            for content in (
                "set -euo pipefail\ncopilotd --environment-name custom\n",
                "set -euo pipefail\n# nixos-config: managed copilotd environment\n",
                'set -euo pipefail\ncopilotd --environment-name "$CODESPACE_NAME" '
                '--environment-name "$CODESPACE_NAME"\n',
            ):
                launcher.write_text(content)
                result = subprocess.run(
                    [sys.executable, str(PATCHER), str(launcher), "/managed/env.sh"],
                    capture_output=True, text=True,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(launcher.read_text(), content)


if __name__ == "__main__":
    unittest.main()
