#!/usr/bin/env python3
"""Check the Copilot activation command preserves other settings and is idempotent."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    copilot = sys.argv[1] if len(sys.argv) > 1 else "copilot"
    with tempfile.TemporaryDirectory(prefix="copilot-settings-test-") as directory:
        home = Path(directory)
        config = home / ".copilot"
        config.mkdir()
        settings = config / "settings.json"
        env = dict(
            os.environ, HOME=directory, COPILOT_HOME=str(config), COPILOT_OFFLINE="true",
        )
        subprocess.run(
            [copilot, "config", "--global", "defaultPermissionMode", "assisted"],
            env=env, check=True, capture_output=True, text=True,
        )
        value = json.loads(settings.read_text())
        assert value["defaultPermissionMode"] == "assisted"
        value["theme"] = "dim"
        settings.write_text(json.dumps(value))
        for _ in range(2):
            subprocess.run(
                [copilot, "config", "--global", "defaultPermissionMode", "assisted"],
                env=env, check=True, capture_output=True, text=True,
            )
            value = json.loads(settings.read_text())
            assert value["defaultPermissionMode"] == "assisted"
            assert value["theme"] == "dim"
        print("PASS: assisted permissions initialize and preserve settings across repeat activation")


if __name__ == "__main__":
    main()
