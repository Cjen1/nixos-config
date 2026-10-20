#!/usr/bin/env python3
"""Check safe, repeatable migration to shared Lake dependencies."""

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


source = Path(os.environ.get(
    "leanShareSource", str(Path(__file__).parent.parent / "modules/home-manager/lean-share.py"),
))
spec = importlib.util.spec_from_file_location("lean_share", source)
share = importlib.util.module_from_spec(spec)
spec.loader.exec_module(share)


class ShareTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.shared = self.root / "shared"
        self.shared.mkdir()
        self.packages = {}
        self.revisions = {}
        for name in ("mathlib", "batteries"):
            package = self.root / "store" / name
            package.mkdir(parents=True)
            (package / "source.lean").write_text("-- original source\n")
            self.git(package, "init", "--quiet")
            self.git(package, "add", ".")
            self.git(package, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                     "commit", "--quiet", "-m", "Fixture")
            self.revisions[name] = self.git(package, "rev-parse", "HEAD").strip()
            self.packages[name] = package
        (self.packages["mathlib"] / "lake-manifest.json").write_text(json.dumps({
            "packages": [{"name": "batteries", "type": "git", "rev": self.revisions["batteries"]}],
        }))
        self.config = {
            "toolchain": "leanprover/lean4:v4.35.0",
            "mathlibRevision": self.revisions["mathlib"],
            "packages": [{"name": name, "dir": str(path)} for name, path in self.packages.items()],
        }
        (self.shared / "config.json").write_text(json.dumps(self.config))
        (self.shared / "package-overrides.json").write_text('{"packages":[]}')
        self.project = self.project_at("project")

    @staticmethod
    def git(path, *arguments):
        return subprocess.check_output(["git", "-C", str(path), *arguments], text=True)

    def project_at(self, name):
        project = self.root / name
        project.mkdir()
        (project / "lean-toolchain").write_text(self.config["toolchain"] + "\n")
        (project / "lake-manifest.json").write_text(json.dumps({
            "packages": [
                {"name": name, "type": "git", "rev": revision}
                for name, revision in self.revisions.items()
            ],
        }))
        (project / "proof.lean").write_text("-- local proof edits\n")
        return project

    def invoke(self, *arguments):
        return subprocess.run(
            [sys.executable, str(source), "--shared", str(self.shared), *map(str, arguments)],
            capture_output=True, text=True,
        )

    def clone_dependencies(self):
        packages = self.project / ".lake/packages"
        packages.mkdir(parents=True)
        for name, path in self.packages.items():
            self.git(self.root, "clone", "--quiet", str(path), str(packages / name))
            cache = packages / name / ".lake/build"
            cache.mkdir(parents=True)
            (cache / "compiled.olean").write_bytes(b"compiled")
            with (packages / name / ".git/info/exclude").open("a") as exclude:
                exclude.write("\n.lake/\n")

    def test_links_and_idempotence_preserve_project_outputs(self):
        build = self.project / ".lake/build"
        build.mkdir(parents=True)
        (build / "project.olean").write_bytes(b"project output")
        for _ in range(2):
            result = self.invoke(self.project)
            self.assertEqual(result.returncode, 0, result.stderr)
        for name, path in self.packages.items():
            self.assertEqual((self.project / ".lake/packages" / name).resolve(), path)
        self.assertEqual((build / "project.olean").read_bytes(), b"project output")
        self.assertEqual((self.project / "proof.lean").read_text(), "-- local proof edits\n")
        result = subprocess.run(
            [sys.executable, str(source), "--shared", str(self.shared), "."],
            cwd=self.project, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_clean_replacement_and_dry_run(self):
        self.clone_dependencies()
        target = self.project / ".lake/packages/mathlib"
        for flags, expected in (([], 1), (["--replace", "--dry-run"], 0)):
            result = self.invoke(*flags, self.project)
            self.assertEqual(result.returncode, expected, result.stderr)
            self.assertFalse(target.is_symlink())
        result = self.invoke("--replace", self.project)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(target.is_symlink())
        self.assertFalse(list(target.parent.glob(".*.lean-share")))

    def test_incompatible_toolchain_or_revision_is_not_changed(self):
        original = (self.project / "lean-toolchain").read_text()
        (self.project / "lean-toolchain").write_text("leanprover/lean4:v4.34.0\n")
        self.assertIn("different Lean toolchain", self.invoke(self.project).stderr)
        (self.project / "lean-toolchain").write_text(original)
        manifest = self.project / "lake-manifest.json"
        data = json.loads(manifest.read_text())
        data["packages"][1]["rev"] = "different"
        manifest.write_text(json.dumps(data))
        self.assertIn("shared dependency revision", self.invoke(self.project).stderr)
        self.assertFalse((self.project / ".lake").exists())

    def test_local_dependency_edits_and_custom_overrides_are_preserved(self):
        self.clone_dependencies()
        edited = self.project / ".lake/packages/mathlib/source.lean"
        edited.write_text("-- changed dependency source\n")
        self.assertIn("local dependency edits", self.invoke("--replace", self.project).stderr)
        self.assertEqual(edited.read_text(), "-- changed dependency source\n")
        edited.write_text("-- original source\n")
        overrides = self.project / ".lake/package-overrides.json"
        overrides.write_text('{"custom":true}')
        self.assertIn("existing package overrides", self.invoke("--replace", self.project).stderr)
        self.assertEqual(overrides.read_text(), '{"custom":true}')

    def test_preflight_all_projects_before_changes(self):
        other = self.project_at("other")
        (other / "lean-toolchain").write_text("leanprover/lean4:v4.34.0\n")
        result = self.invoke(self.project, other)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.project / ".lake").exists())

    def test_active_process_blocks_replacement(self):
        process = subprocess.Popen(
            [sys.executable, "-c", "import time; time.sleep(60)"], cwd=self.project,
        )
        try:
            result = self.invoke(self.project)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(f"PID {process.pid}", result.stderr)
        finally:
            process.terminate()
            process.wait()

    def test_interrupted_link_and_cleanup_are_resumable(self):
        self.clone_dependencies()
        prepared = share.plan(self.project, self.shared, self.config, True)
        with patch.object(share.os, "replace", side_effect=OSError("interrupted link")):
            with self.assertRaisesRegex(OSError, "interrupted link"):
                share.apply(*prepared)
        with patch.object(share.shutil, "rmtree", side_effect=OSError("interrupted cleanup")):
            with self.assertRaisesRegex(OSError, "interrupted cleanup"):
                share.apply(*share.plan(self.project, self.shared, self.config, True))
        result = self.invoke("--replace", self.project)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(list((self.project / ".lake/packages").glob(".*.lean-share")))

    def test_existing_shared_packages_directory(self):
        self.clone_dependencies()
        original = self.project / ".lake/packages"
        legacy = self.root / "legacy-packages"
        original.rename(legacy)
        original.symlink_to(legacy)
        other = self.project_at("other")
        (other / ".lake").mkdir()
        (other / ".lake/packages").symlink_to(legacy)
        with patch.object(share.shutil, "rmtree", side_effect=OSError("interrupted cleanup")):
            with self.assertRaisesRegex(OSError, "interrupted cleanup"):
                share.apply(*share.plan(self.project, self.shared, self.config, True))
        result = self.invoke("--replace", self.project, other)
        self.assertEqual(result.returncode, 0, result.stderr)
        for project in (self.project, other):
            self.assertEqual((project / ".lake/packages/mathlib").resolve(), self.packages["mathlib"])

    def test_build_in_another_project_blocks_shared_cache_replacement(self):
        self.clone_dependencies()
        other = self.project_at("other")
        (other / ".lake").mkdir()
        (other / ".lake/packages").symlink_to(self.project / ".lake/packages")
        process = subprocess.Popen(
            [
                sys.executable, "-c",
                "import ctypes, time; ctypes.CDLL(None).prctl(15, b'lake', 0, 0, 0); "
                "print('ready', flush=True); time.sleep(60)",
            ], cwd=other, stdout=subprocess.PIPE, text=True,
        )
        try:
            self.assertEqual(process.stdout.readline().strip(), "ready")
            result = self.invoke("--replace", self.project)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(f"PID {process.pid}", result.stderr)
            self.assertFalse((self.project / ".lake/packages/mathlib").is_symlink())
        finally:
            process.terminate()
            process.wait()
            process.stdout.close()


if __name__ == "__main__":
    unittest.main()
