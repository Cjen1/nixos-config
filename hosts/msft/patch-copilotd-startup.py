#!/usr/bin/env python3
"""Load the Home Manager environment in the local Codespace daemon launcher."""

import os
from pathlib import Path
import shlex
import stat
import sys
import tempfile


launcher = Path(sys.argv[1])
environment = shlex.quote(sys.argv[2])
marker = "# nixos-config: managed copilotd environment"
block = (
    f"{marker}\n"
    f"if [ -r {environment} ]; then\n"
    f"  . {environment}\n"
    "fi\n"
)
anchor = "set -euo pipefail\n"

if launcher.is_symlink():
    sys.exit(f"error: refusing to patch symlink: {launcher}")
if not launcher.exists():
    print(f"Skipping copilotd startup patch: {launcher} is absent")
    sys.exit(0)
if not launcher.is_file():
    sys.exit(f"error: copilotd launcher is not a regular file: {launcher}")

original = launcher.read_text()
if marker in original:
    if original.count(marker) != 1 or original.count(block) != 1:
        sys.exit(f"error: unexpected managed copilotd startup patch in {launcher}")
    print(f"Copilotd startup environment already patched: {launcher}")
    sys.exit(0)
if original.count(anchor) != 1:
    sys.exit(f"error: cannot locate unique copilotd startup patch point in {launcher}")

updated = original.replace(anchor, f"{anchor}\n{block}", 1)
with tempfile.NamedTemporaryFile(
    mode="w", dir=launcher.parent, prefix=".nixos-config-copilotd-", delete=False
) as stream:
    temporary = Path(stream.name)
    try:
        stream.write(updated)
        stream.flush()
        os.fchmod(stream.fileno(), stat.S_IMODE(launcher.stat().st_mode))
        os.replace(temporary, launcher)
    finally:
        temporary.unlink(missing_ok=True)
print(f"Patched copilotd startup environment: {launcher}")
