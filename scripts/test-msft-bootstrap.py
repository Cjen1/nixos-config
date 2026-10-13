#!/usr/bin/env python3
"""Exercise bootstrap transport and remote deployment without a live machine."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}")

    def executable(self, name, body):
        path = self.bin / name
        path.write_text(f"#!{sys.executable}\n" + body)
        path.chmod(0o755)
        return path

    def test_transport(self):
        call = self.root / "ssh.json"
        self.env.update(
            MSFT_FLEET_FILE=os.environ["fleetFile"],
            MSFT_BOOTSTRAP_SCRIPT=os.environ["remoteBootstrap"],
            SSH_CALL=str(call),
        )
        self.executable(
            "ssh",
            "import json, os, sys\n"
            "from pathlib import Path\n"
            "Path(os.environ['SSH_CALL']).write_text(json.dumps({"
            "'args':sys.argv[1:], 'script':sys.stdin.read(), "
            "'prompt':os.environ.get('GH_PROMPT_DISABLED')}))\n"
            "sys.exit(int(os.environ.get('SSH_EXIT', '0')))\n",
        )
        for alias in ("cs1", "cs2", "aci1"):
            result = subprocess.run(
                ["bash", os.environ["bootstrapSource"], alias],
                env=self.env, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            invocation = json.loads(call.read_text())
            self.assertEqual(invocation["args"], [
                "-T", "-o", "BatchMode=yes", "-o", "ConnectionAttempts=1",
                "-o", "ConnectTimeout=30", "-o", "ServerAliveInterval=30",
                "-o", "ServerAliveCountMax=3", alias,
                "bash -s -- https://github.com/Cjen1/nixos-config.git /root/nixos-config",
            ])
            self.assertEqual(invocation["prompt"], "1")
            self.assertEqual(
                invocation["script"], Path(os.environ["remoteBootstrap"]).read_text(),
            )
        self.env["SSH_EXIT"] = "255"
        result = subprocess.run(
            ["bash", os.environ["bootstrapSource"], "cs1"],
            env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 255)
        self.assertIn("bootstrap failed for cs1", result.stderr)
        call.unlink()
        for args in ([], ["missing"], ["-bad"], ["cs1;touch nope"], ["cs1", "cs2"]):
            result = subprocess.run(
                ["bash", os.environ["bootstrapSource"], *args],
                env=self.env, capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(call.exists())
        invalid_registry = self.root / "invalid-registry.json"
        self.env["MSFT_FLEET_FILE"] = str(invalid_registry)
        for entry in (
            {"kind": "unknown", "data": {"name": "one"}},
            {"kind": "codespace", "data": {}},
            {"kind": "ssh", "data": {"name": "wrong-field"}},
        ):
            invalid_registry.write_text(json.dumps({"cs1": entry}))
            result = subprocess.run(
                ["bash", os.environ["bootstrapSource"], "cs1"],
                env=self.env, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 1)
            self.assertFalse(call.exists())

    def git(self, directory, *args):
        return subprocess.run(
            ["git", "-C", str(directory), *args], env=self.env,
            capture_output=True, text=True, check=True,
        ).stdout.strip()

    def prepare_remote(self):
        self.origin = self.root / "origin"
        self.origin.mkdir()
        self.git(self.origin, "init", "-b", "main")
        self.env.update(
            GIT_AUTHOR_NAME="Fixture", GIT_COMMITTER_NAME="Fixture",
            GIT_AUTHOR_EMAIL="fixture@example.invalid",
            GIT_COMMITTER_EMAIL="fixture@example.invalid",
            GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_SYSTEM="/dev/null",
        )
        (self.origin / "tracked").write_text("one")
        self.git(self.origin, "add", ".")
        self.git(self.origin, "commit", "-m", "initial")
        self.checkout = self.root / "checkout"
        self.activation = self.root / "activation"
        self.activation.mkdir()
        activate = self.activation / "activate"
        activate.write_text(
            f"#!{sys.executable}\n"
            "import os, sys\nfrom pathlib import Path\n"
            "with Path(os.environ['ACTIVATIONS']).open('a') as f: f.write('activated\\n')\n"
            "sys.exit(int(os.environ.get('ACTIVATE_EXIT', '0')))\n"
        )
        activate.chmod(0o755)
        self.env.update(
            ACTIVATIONS=str(self.root / "activations"),
            ACTIVATION=str(self.activation), NIX_CALL=str(self.root / "nix.json"),
        )
        self.executable("id", "import os\nprint(os.environ.get('REMOTE_UID', '0'))\n")
        self.executable(
            "nix",
            "import json, os, sys\nfrom pathlib import Path\n"
            "Path(os.environ['NIX_CALL']).write_text(json.dumps(sys.argv[1:]))\n"
            "print(os.environ['ACTIVATION'])\n"
            "sys.exit(int(os.environ.get('NIX_EXIT', '0')))\n",
        )
        self.executable("curl", "raise RuntimeError('Nix already installed: must not download')\n")

    def run_remote(self, status=0, message=None):
        result = subprocess.run(
            ["bash", os.environ["remoteBootstrap"], str(self.origin), str(self.checkout)],
            env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, status, result.stdout + result.stderr)
        if message:
            self.assertIn(message, result.stderr)
        return result

    def test_clone_repeat_and_fast_forward(self):
        self.prepare_remote()
        self.run_remote()
        self.run_remote()
        (self.origin / "tracked").write_text("two")
        self.git(self.origin, "commit", "-am", "update")
        self.run_remote()
        self.assertEqual((self.checkout / "tracked").read_text(), "two")
        self.assertEqual(
            self.git(self.checkout, "rev-parse", "HEAD"),
            self.git(self.origin, "rev-parse", "main"),
        )
        self.assertEqual((self.root / "activations").read_text(), "activated\n" * 3)
        args = json.loads((self.root / "nix.json").read_text())
        self.assertEqual(args[:4], [
            "--extra-experimental-features", "nix-command flakes", "build",
            "./hosts/msft#homeConfigurations.remote.activationPackage",
        ])
        self.assertIn("--no-write-lock-file", args)

    def test_checkout_guards(self):
        self.prepare_remote()
        self.run_remote()
        (self.checkout / "untracked").touch()
        self.run_remote(1, "dirty checkout")
        (self.checkout / "untracked").unlink()
        (self.checkout / "tracked").write_text("local")
        self.run_remote(1, "dirty checkout")
        self.git(self.checkout, "commit", "-am", "local-only")
        self.run_remote(1, "not on origin/main")
        self.git(self.checkout, "checkout", "-b", "other")
        self.run_remote(1, "must be on branch main")
        self.git(self.checkout, "remote", "set-url", "origin", "unexpected")
        self.run_remote(1, "unexpected origin")
        self.assertEqual((self.root / "activations").read_text(), "activated\n")

    def test_prerequisites_and_failures(self):
        self.prepare_remote()
        self.env["REMOTE_UID"] = "1000"
        self.run_remote(1, "requires root")
        self.assertFalse(self.checkout.exists())
        self.env["REMOTE_UID"] = "0"
        self.checkout.mkdir()
        self.run_remote(1, "not a Git checkout")
        self.checkout.rmdir()
        self.env["NIX_EXIT"] = "9"
        self.run_remote(9, "building remote Home Manager failed")
        self.assertFalse((self.root / "activations").exists())
        self.env["NIX_EXIT"] = "0"
        self.env["ACTIVATE_EXIT"] = "8"
        self.run_remote(8, "activating remote Home Manager failed")
        self.env["ACTIVATE_EXIT"] = "0"
        self.run_remote()

    def test_install_failure(self):
        self.prepare_remote()
        # Isolate PATH so no host Nix binary can mask the first-install path.
        bash = shutil.which("bash")
        for tool in ("git", "sh", "nproc"):
            (self.bin / tool).symlink_to(shutil.which(tool))
        (self.bin / "nix").unlink()
        self.env["PATH"] = str(self.bin)
        self.executable("curl", "import sys\nsys.exit(6)\n")
        result = subprocess.run(
            [bash, os.environ["remoteBootstrap"], str(self.origin), str(self.checkout)],
            env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 6, result.stderr)
        self.assertIn("installing Nix failed", result.stderr)
        self.assertFalse(self.checkout.exists())

    def test_first_install_and_repeat(self):
        self.prepare_remote()
        bash = shutil.which("bash")
        for tool in ("git", "sh", "nproc"):
            (self.bin / tool).symlink_to(shutil.which(tool))
        template = self.root / "nix-template"
        (self.bin / "nix").rename(template)
        self.env["PATH"] = str(self.bin)
        installer = self.root / "installer.py"
        installer.write_text(
            "import os, shutil, sys\nfrom pathlib import Path\n"
            f"shutil.copyfile({str(template)!r}, {str(self.bin / 'nix')!r})\n"
            f"Path({str(self.bin / 'nix')!r}).chmod(0o755)\n"
            f"Path({str(self.root / 'installer-args')!r}).write_text(repr(sys.argv[1:]))\n"
        )
        install_command = (
            f"exec {shlex.quote(sys.executable)} {shlex.quote(str(installer))} \"$@\""
        )
        self.executable("curl", f"print({install_command!r})\n")
        for _ in range(2):
            result = subprocess.run(
                [bash, os.environ["remoteBootstrap"], str(self.origin), str(self.checkout)],
                env=self.env, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            (self.root / "installer-args").read_text(),
            repr(["install", "linux", "--init", "none", "--no-confirm"]),
        )
        self.assertEqual((self.root / "activations").read_text(), "activated\n" * 2)

    def test_packaged_usage(self):
        result = subprocess.run(
            [str(Path(os.environ["bootstrap"]) / "bin/bootstrap-codespace-nix-env")],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 64)
        self.assertIn("Usage: bootstrap-codespace-nix-env", result.stderr)


if __name__ == "__main__":
    unittest.main()
