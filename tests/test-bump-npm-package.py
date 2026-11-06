#!/usr/bin/env python3
"""Offline checks; --integration verifies cache hashes; --benchmark times real bumps."""

import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
PACKAGES = {
    "modules/home-manager/codex-cli": "@openai/codex",
    "modules/home-manager/github-copilot-cli": "@github/copilot",
    "modules/home-manager/opencode-cli": "opencode-ai",
    "hosts/msft/claude-code": "@anthropic-ai/claude-code",
}
HASH = "sha256-" + base64.b64encode(bytes(range(32))).decode()
STUB = r"""#!/usr/bin/env python3
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
record = {"command": name, "args": args}
if name == "prefetch-npm-deps":
    record["lock"] = json.loads(pathlib.Path(args[0]).read_text())
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps(record) + "\n")
if os.environ.get("FAIL_COMMAND") == name or (
    name == "nix" and args[0] == os.environ.get("FAIL_NIX_ACTION")
):
    sys.exit(17)
if name == "nix":
    if args[0] == "shell":
        command = args[args.index("-c") + 1:]
        os.execvp(command[0], command)
    elif args[0] == "eval":
        print(os.environ["PREVIOUS_CACHE"])
    elif args[0] == "hash":
        cache = pathlib.Path(args[-1])
        with open(os.environ["CACHE_SNAPSHOT"], "w") as snapshot:
            json.dump({
                "files": sorted(str(p.relative_to(cache)) for p in cache.rglob("*") if p.is_file()),
                "lock": json.loads((cache / "package-lock.json").read_text()),
            }, snapshot)
        print(os.environ["NEW_HASH"])
    elif args[0] == "store":
        print(args[-1])
elif name == "npm":
    dependency, version = args[-1].rsplit("@", 1)
    if version == "latest":
        version = os.environ.get("RESOLVED_VERSION", "2.0.0")
    pkg = json.loads(pathlib.Path("package.json").read_text())
    lock = json.loads(pathlib.Path("package-lock.json").read_text())
    pkg["dependencies"][dependency] = version
    lock["packages"][""]["dependencies"][dependency] = version
    lock["packages"]["node_modules/" + dependency]["version"] = version
    for filename, value in [("package.json", pkg), ("package-lock.json", lock)]:
        pathlib.Path(filename).write_text(json.dumps(value, indent=2) + "\n")
"""


class BumpTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        subprocess.run(["git", "init", "-q", self.root], check=True)
        shutil.copytree(ROOT / "scripts", self.root / "scripts")
        tools = self.root / "bin"
        tools.mkdir()
        for name in ["nix", "npm", "prefetch-npm-deps"]:
            tool = tools / name
            tool.write_text(STUB)
            tool.chmod(0o755)
        self.env = {
            **os.environ, "PATH": f"{tools}:{os.environ['PATH']}",
            "CALL_LOG": str(self.root / "calls.jsonl"),
            "PREVIOUS_CACHE": str(self.root / "previous"),
            "CACHE_SNAPSHOT": str(self.root / "snapshot.json"),
            "NEW_HASH": HASH,
        }

    def fixture(self, location, dependency):
        package = self.root / location
        package.mkdir(parents=True)
        wrapper = next(path for path, name in PACKAGES.items() if name == dependency)
        shutil.copy2(ROOT / wrapper / "bump.sh", package / "bump.sh")
        pkg = {"name": "test", "version": "1.0.0", "dependencies": {dependency: "1.0.0"}}
        lock = {
            **pkg, "lockfileVersion": 3, "requires": True,
            "packages": {
                "": pkg.copy(),
                f"node_modules/{dependency}": {
                    "version": "1.0.0", "resolved": "https://registry.npmjs.org/test.tgz",
                    "integrity": "sha512-" + base64.b64encode(bytes(64)).decode(),
                },
            },
        }
        for filename, value in [("package.json", pkg), ("package-lock.json", lock)]:
            (package / filename).write_text(json.dumps(value, indent=2) + "\n")
        (package / "default.nix").write_text(
            f'{{ version = "1.0.0"; npmDepsHash = "{HASH}"; unrelated = true; }}\n'
        )
        return package, lock

    def run_bump(self, package, *args, success=True):
        result = subprocess.run(
            ["bash", package / "bump.sh", *args], env=self.env,
            text=True, capture_output=True,
        )
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return [json.loads(line) for line in Path(self.env["CALL_LOG"]).read_text().splitlines()]

    def test_all_wrappers_update_without_build(self):
        for location, dependency in PACKAGES.items():
            with self.subTest(location=location):
                Path(self.env["CALL_LOG"]).unlink(missing_ok=True)
                package, _ = self.fixture(location, dependency)
                calls = self.run_bump(package)
                self.assertEqual(sum(c["command"] == "npm" for c in calls), 1)
                self.assertEqual(sum(c["command"] == "prefetch-npm-deps" for c in calls), 1)
                self.assertFalse(any(c["args"][0] == "build" for c in calls))
                lock = json.loads((package / "package-lock.json").read_text())
                pkg = json.loads((package / "package.json").read_text())
                self.assertEqual(pkg["version"], "2.0.0")
                self.assertEqual(lock["version"], pkg["version"])
                self.assertEqual(lock["packages"][""]["version"], pkg["version"])
                self.assertEqual(lock["packages"][""]["dependencies"], pkg["dependencies"])
                self.assertIn('unrelated = true;', (package / "default.nix").read_text())
                snapshot = json.loads(Path(self.env["CACHE_SNAPSHOT"]).read_text())
                self.assertEqual(snapshot["lock"], lock)
                self.assertNotIn("missing-package-lock.json", snapshot["files"])

    def test_unchanged_lock_skips_prefetch_and_build_is_opt_in(self):
        location, dependency = next(iter(PACKAGES.items()))
        package, _ = self.fixture(location, dependency)
        previous = Path(self.env["PREVIOUS_CACHE"])
        previous.mkdir()
        shutil.copy2(package / "package-lock.json", previous / "package-lock.json")
        calls = self.run_bump(package, "--build", "1.0.0")
        self.assertFalse(any(c["command"] == "prefetch-npm-deps" for c in calls))
        builds = [c for c in calls if c["command"] == "nix" and c["args"][0] == "build"]
        self.assertEqual(len(builds), 1)
        self.assertIn("--cores", builds[0]["args"])

    def test_reuses_previous_cache_and_fetches_only_missing(self):
        location, dependency = next(iter(PACKAGES.items()))
        package, lock = self.fixture(location, dependency)
        entry = lock["packages"][f"node_modules/{dependency}"]
        key = "make-fetch-happen:request-cache:" + entry["resolved"]
        index_hash = hashlib.sha256(key.encode()).hexdigest()
        index_path = Path("_cacache/index-v5") / index_hash[:2] / index_hash[2:4] / index_hash[4:]
        content_path = Path("_cacache/content-v2/sha512/00/00") / ("00" * 62)
        previous = Path(self.env["PREVIOUS_CACHE"])
        for path, data in [
            (index_path, "checksum\t" + json.dumps({"key": key, "integrity": entry["integrity"]})),
            (content_path, "cached tarball"),
        ]:
            target = previous / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(data)
        lock["packages"]["node_modules/new"] = {
            **entry, "resolved": "https://registry.npmjs.org/new.tgz",
        }
        (package / "package-lock.json").write_text(json.dumps(lock, indent=2) + "\n")
        calls = self.run_bump(package)
        prefetch = next(c for c in calls if c["command"] == "prefetch-npm-deps")
        self.assertEqual(set(prefetch["lock"]["packages"]), {"", "node_modules/new"})
        files = json.loads(Path(self.env["CACHE_SNAPSHOT"]).read_text())["files"]
        self.assertIn(str(index_path), files)
        self.assertIn(str(content_path), files)

    def test_command_failures_are_not_reported_as_success(self):
        for failure in ["npm", "prefetch-npm-deps", "eval", "hash", "store", "build"]:
            with self.subTest(failure=failure):
                package, _ = self.fixture("test-" + failure, "@openai/codex")
                self.env.pop("FAIL_COMMAND", None)
                self.env.pop("FAIL_NIX_ACTION", None)
                self.env["FAIL_COMMAND" if failure in ["npm", "prefetch-npm-deps"]
                         else "FAIL_NIX_ACTION"] = failure
                self.run_bump(package, "--build", success=False)

    def test_invalid_arguments_do_not_update_manifests(self):
        location, dependency = next(iter(PACKAGES.items()))
        package, _ = self.fixture(location, dependency)
        original = (package / "package.json").read_bytes()
        calls = self.run_bump(package, "--unknown", success=False)
        self.assertEqual((package / "package.json").read_bytes(), original)
        self.assertFalse(any(c["command"] == "npm" for c in calls))


def integration():
    location = "modules/home-manager/codex-cli"
    version = json.loads((ROOT / location / "package.json").read_text())["version"]
    jobs = str(max(1, ((os.cpu_count() or 1) + 1) >> 1))
    base_expr = (
        f'let flake = builtins.getFlake "git+file://{ROOT}?dir=hosts/mercury"; '
        'pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux; '
        f'in (pkgs.callPackage {ROOT / location} {{}}).npmDeps'
    )
    subprocess.run([
        "nix", "build", "--impure", "--no-link", "--max-jobs", jobs,
        "--cores", jobs, "--expr", base_expr,
    ], cwd=ROOT, check=True)
    with tempfile.TemporaryDirectory(prefix=".bump-integration-", dir=ROOT) as temp:
        package = Path(temp)
        for filename in ["package.json", "package-lock.json", "default.nix", "bump.sh"]:
            shutil.copy2(ROOT / location / filename, package / filename)
        pkg = json.loads((package / "package.json").read_text())
        pkg["dependencies"]["detect-libc"] = "2.1.2"
        (package / "package.json").write_text(json.dumps(pkg, indent=2) + "\n")
        result = subprocess.run(
            ["bash", package / "bump.sh", version], cwd=ROOT,
            text=True, capture_output=True, check=True,
        )
        print(result.stdout, end="")
        assert re.search(r"Reusing [1-9]\d* cached dependencies; prefetching 1 lockfile entries", result.stdout)
        tools = (
            f'let flake = builtins.getFlake "git+file://{ROOT}?dir=hosts/mercury"; '
            'in flake.inputs.nixpkgs.legacyPackages.x86_64-linux.prefetch-npm-deps'
        )
        expected_hash = subprocess.check_output([
            "nix", "shell", "--impure", "--expr", tools,
            "-c", "prefetch-npm-deps", str(package / "package-lock.json"),
        ], cwd=ROOT, text=True).strip()
        actual_hash = re.search(r'npmDepsHash = "([^"]+)";', (package / "default.nix").read_text())[1]
        assert actual_hash == expected_hash, (actual_hash, expected_hash)
        result = subprocess.run(
            ["bash", package / "bump.sh", version, "--build"], cwd=ROOT,
            text=True, capture_output=True, check=True,
        )
        assert not re.search(r"building '[^'\n]*-npm-deps\.drv'", result.stderr), result.stderr
        print("Merged cache matches the pinned prefetcher; full build reused the imported cache.")


def benchmark(baseline_revision):
    location = "modules/home-manager/codex-cli"
    dependency = PACKAGES[location]
    version = json.loads((ROOT / location / "package.json").read_text())["version"]
    original = subprocess.check_output(
        ["git", "show", f"{baseline_revision}:{location}/bump.sh"], cwd=ROOT, text=True,
    )
    for label, script in [("Before", original), ("After", (ROOT / location / "bump.sh").read_text())]:
        with tempfile.TemporaryDirectory(prefix=".bump-benchmark-", dir=ROOT) as temp:
            package = Path(temp)
            for filename in ["package.json", "package-lock.json", "default.nix"]:
                shutil.copy2(ROOT / location / filename, package / filename)
            (package / "bump.sh").write_text(script)
            start = time.monotonic()
            subprocess.run(["bash", package / "bump.sh", version], cwd=ROOT, check=True)
            print(f"{label}: {time.monotonic() - start:.2f} seconds", flush=True)
            assert json.loads((package / "package.json").read_text())["dependencies"][dependency] == version


if __name__ == "__main__":
    try:
        if len(sys.argv) == 3 and sys.argv[1] == "--benchmark":
            benchmark(sys.argv[2])
        elif sys.argv[1:] == ["--integration"]:
            integration()
        else:
            unittest.main()
    except subprocess.CalledProcessError as error:
        print(error.stdout or "", end="", file=sys.stderr)
        print(error.stderr or "", end="", file=sys.stderr)
        raise
