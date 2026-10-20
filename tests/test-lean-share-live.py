#!/usr/bin/env python3
"""Compile a real Lean project using only the shared dependency symlinks."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--shared", type=Path, required=True)
parser.add_argument("--lake", type=Path, required=True)
args = parser.parse_args()
config = json.loads((args.shared / "config.json").read_text())
packages = {package["name"]: Path(package["dir"]) for package in config["packages"]}
manifest = json.loads((packages["mathlib"] / "lake-manifest.json").read_text())
manifest["name"] = "shared_smoke"
manifest["packages"].append({
    "name": "mathlib", "type": "git",
    "url": "https://github.com/leanprover-community/mathlib4.git",
    "rev": config["mathlibRevision"], "inputRev": "v4.35.0",
    "inherited": False, "manifestFile": "lake-manifest.json", "configFile": "lakefile.lean",
})
environment = dict(
    os.environ,
    LAKE_NO_CACHE="1",
    LEAN_NUM_THREADS=str((os.cpu_count() + 1) >> 1),
)
with tempfile.TemporaryDirectory(prefix="lean-share-live-") as directory:
    project = Path(directory)
    (project / "lean-toolchain").write_text(config["toolchain"] + "\n")
    (project / "lake-manifest.json").write_text(json.dumps(manifest))
    (project / "lakefile.toml").write_text(
        'name = "shared_smoke"\nversion = "0.1.0"\ndefaultTargets = ["Smoke"]\n'
        '[[require]]\nname = "mathlib"\n'
        'git = "https://github.com/leanprover-community/mathlib4.git"\nrev = "v4.35.0"\n'
        '[[lean_lib]]\nname = "Smoke"\n'
    )
    (project / "Smoke.lean").write_text(
        "module\nimport Mathlib.Data.Nat.Basic\nexample (n : Nat) : n + 0 = n := by simp\n"
    )
    subprocess.run(
        ["lean-share", str(project)], check=True,
    )
    for _ in range(2):
        subprocess.run([str(args.lake), "build"], cwd=project, env=environment, check=True)
    if not (project / ".lake/build/lib/lean/Smoke.olean").is_file():
        raise SystemExit("Project did not produce its own compiled Lean module")
    for name, package in packages.items():
        link = project / ".lake/packages" / name
        if not link.is_symlink() or link.resolve() != package:
            raise SystemExit(f"{name} was copied instead of linked")
    print("Real Mathlib import compiled twice; all shared dependencies remain symlinks")
