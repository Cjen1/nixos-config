#!/usr/bin/env python3
"""Link compatible Lake projects to the Home Manager-managed Lean packages."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def check_processes(paths):
    ancestors = set()
    pid = os.getpid()
    while pid > 1:
        ancestors.add(str(pid))
        status = Path(f"/proc/{pid}/status").read_text()
        pid = int(next(line.split()[1] for line in status.splitlines() if line.startswith("PPid:")))
    for process in Path("/proc").iterdir():
        if not process.name.isdecimal():
            continue
        try:
            if process.stat().st_uid != os.getuid():
                continue
            command = (process / "comm").read_text().strip()
            if process.name in ancestors and command not in ("lean", "lake", "lake.orig", "leanchecker"):
                continue
            locations = [(process / name).resolve(strict=True) for name in ("cwd", "exe")]
            if command in ("lean", "lake", "lake.orig", "leanchecker"):
                for parent in (locations[0], *locations[0].parents):
                    manifest = parent / "lake-manifest.json"
                    if manifest.is_file():
                        data = json.loads(manifest.read_text())
                        packages = parent / data.get("packagesDir", ".lake/packages")
                        if packages.is_dir():
                            locations.extend(package.resolve() for package in packages.iterdir())
                        break
            if any(location.is_relative_to(path) for location in locations for path in paths):
                raise ValueError(f"PID {process.name} is using this project or its dependencies")
            for descriptor in (process / "fd").iterdir():
                try:
                    location = descriptor.resolve(strict=True)
                except (FileNotFoundError, ProcessLookupError):
                    continue
                if any(location.is_relative_to(path) for path in paths):
                    raise ValueError(f"PID {process.name} is using this project's dependencies")
        except (FileNotFoundError, ProcessLookupError):
            continue
        except PermissionError:
            command = (process / "comm").read_text().strip()
            if command in ("lean", "lake", "lake.orig", "leanchecker"):
                raise ValueError(f"Cannot inspect active {command} PID {process.name}; refusing migration")


def clean_checkout(path, revision):
    if not (path / ".git").exists():
        raise ValueError(f"{path}: not a dependency Git checkout; refusing to replace it")
    environment = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
    head = subprocess.check_output(
        ["git", "-C", str(path), "rev-parse", "HEAD"], env=environment, text=True,
    ).strip()
    if head != revision:
        raise ValueError(f"{path} is at {head}, expected {revision}")
    status = subprocess.check_output(
        ["git", "-C", str(path), "status", "--porcelain=v1", "--untracked-files=normal"],
        env=environment, text=True,
    )
    if status:
        raise ValueError(f"{path} has local dependency edits; refusing to replace it")


def plan(project, shared, config, replace):
    project = project.resolve(strict=True)
    if (project / "lean-toolchain").read_text().strip() != config["toolchain"]:
        raise ValueError(f"{project}: requires a different Lean toolchain")
    manifest = json.loads((project / "lake-manifest.json").read_text())
    mathlib = next(package for package in config["packages"] if package["name"] == "mathlib")
    dependency_manifest = json.loads((Path(mathlib["dir"]) / "lake-manifest.json").read_text())
    revisions = {
        package["name"]: package["rev"] for package in dependency_manifest["packages"]
        if package["type"] == "git"
    }
    revisions["mathlib"] = config["mathlibRevision"]
    locked = {package["name"]: package for package in manifest["packages"]}
    lake = project / ".lake"
    if lake.is_symlink():
        raise ValueError(f"{lake}: refusing a symlinked project build directory")
    overrides = lake / "package-overrides.json"
    expected = shared / "package-overrides.json"
    if overrides.exists() or overrides.is_symlink():
        if not overrides.is_symlink() or overrides.resolve() != expected.resolve():
            raise ValueError(f"{overrides}: refusing to overwrite existing package overrides")
    targets = []
    for package in config["packages"]:
        name = package["name"]
        if not name or Path(name).name != name or name in (".", ".."):
            raise ValueError(f"Invalid shared package name: {name!r}")
        if locked.get(name, {}).get("rev") != revisions[name]:
            raise ValueError(f"{project}: {name} does not match the shared dependency revision")
        target = project / manifest.get("packagesDir", ".lake/packages") / name
        if target.parent.resolve() == project or not target.parent.resolve().is_relative_to(project):
            if not (lake / "packages").is_symlink() or target.parent != lake / "packages":
                raise ValueError(f"{target}: package directory is outside the project")
        destination = Path(package["dir"]).resolve(strict=True)
        transaction = target.parent / f".{name}.lean-share"
        state = {"target": str(target.parent.resolve() / name), "destination": str(destination)}
        if transaction.is_symlink():
            raise ValueError(f"{transaction}: refusing a symlinked cleanup transaction")
        if transaction.exists():
            contents = list(transaction.iterdir())
            if contents and not (transaction / "state.json").is_file():
                raise ValueError(f"{transaction}: missing migration state")
            if contents and json.loads((transaction / "state.json").read_text()) != state:
                raise ValueError(f"{transaction}: unexpected interrupted migration")
            if any(child.name not in ("state.json", "old") for child in transaction.iterdir()):
                raise ValueError(f"{transaction}: unexpected migration files")
        linked = target.is_symlink() and target.resolve() == destination
        if transaction.exists() and not linked and (transaction / "old").exists():
            clean_checkout(transaction / "old", revisions[name])
        if not linked and target.exists() and not target.is_symlink():
            if not replace:
                raise ValueError(f"{target}: existing checkout; rerun with --replace to reclaim it")
            if transaction.exists() and list(transaction.iterdir()):
                raise ValueError(f"{target}: both an old checkout and a migration transaction exist")
            clean_checkout(target, revisions[name])
        if transaction.exists() and not replace:
            raise ValueError(f"{transaction}: rerun with --replace to finish cleanup")
        if not linked and target.is_symlink() and not replace:
            raise ValueError(f"{target}: existing symlink; rerun with --replace")
        targets.append((target, destination, transaction, state))
    check_processes([project] + [
        target.resolve() for target, _, _, _ in targets
        if target.exists() and not target.is_symlink()
    ] + [transaction.resolve() for _, _, transaction, _ in targets])
    return overrides, expected, targets


def apply(overrides, expected, targets):
    overrides.parent.mkdir(parents=True, exist_ok=True)
    if not overrides.is_symlink():
        overrides.symlink_to(expected)
    for target, destination, transaction, state in targets:
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and not target.is_symlink():
            transaction.mkdir(exist_ok=True)
            (transaction / "state.json").write_text(json.dumps(state))
            target.rename(transaction / "old")
        if not target.is_symlink() or target.resolve() != destination:
            temporary = target.parent / f".{target.name}.lean-share-link"
            if temporary.exists() or temporary.is_symlink():
                if not temporary.is_symlink() or temporary.resolve() != destination:
                    raise ValueError(f"{temporary}: unexpected temporary link")
            else:
                temporary.symlink_to(destination)
            os.replace(temporary, target)
        if transaction.exists():
            old = transaction / "old"
            if old.exists():
                if old.is_symlink():
                    raise ValueError(f"{old}: refusing symlinked cleanup data")
                shutil.rmtree(old)
            (transaction / "state.json").unlink(missing_ok=True)
            transaction.rmdir()


def main():
    parser = argparse.ArgumentParser(prog="lean-share", description=__doc__)
    parser.add_argument("--shared", type=Path, required=True, help=argparse.SUPPRESS)
    parser.add_argument("--replace", action="store_true", help="replace clean matching dependency checkouts")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("projects", type=Path, nargs="+")
    args = parser.parse_args()
    try:
        shared = args.shared.resolve(strict=True)
        config = json.loads((shared / "config.json").read_text())
        plans = [plan(project, shared, config, args.replace) for project in args.projects]
        for project, prepared in zip(args.projects, plans):
            if not args.dry_run:
                apply(*prepared)
            print(f"{project}: {'compatible' if args.dry_run else 'linked'} to {shared}")
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
