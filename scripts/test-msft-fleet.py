#!/usr/bin/env python3
"""Check fleet SSH integration and keepalive invocation without live Codespaces."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class FleetTests(unittest.TestCase):
    def test_registry_shape(self):
        self.assertEqual(
            json.loads(Path(os.environ["fleetFile"]).read_text()),
            {
                "cs1": {"kind": "codespace", "data": {"name": "magical-unicorn-workspace"}},
                "cs2": {"kind": "codespace", "data": {"name": "second-codespace"}},
                "aci1": {"kind": "ssh", "data": {"destination": "root@example.invalid"}},
                "server": {"kind": "ssh", "data": {"destination": "server.example.invalid"}},
            },
        )

    def test_keepalive(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            gh = root / "gh"
            gh.write_text(
                f"#!{sys.executable}\n"
                "import json, os, sys\n"
                "from pathlib import Path\n"
                "Path(os.environ['GH_CALL']).write_text(json.dumps({"
                "'args': sys.argv[1:], "
                "'prompt': os.environ.get('GH_PROMPT_DISABLED')}))\n"
                "print('synthetic connection failure', file=sys.stderr)\n"
                "sys.exit(int(os.environ['GH_EXIT']))\n"
            )
            gh.chmod(0o755)
            call = root / "call.json"
            env = dict(
                os.environ,
                PATH=f"{root}:{os.environ['PATH']}",
                MSFT_FLEET_FILE=os.environ["fleetFile"],
                GH_CALL=str(call),
                GH_EXIT="7",
            )
            for alias, codespace in (
                ("cs1", "magical-unicorn-workspace"), ("cs2", "second-codespace"),
            ):
                with self.subTest(alias=alias):
                    result = subprocess.run(
                        ["bash", os.environ["keepAliveSource"], alias],
                        env=env, capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, 7, result.stderr)
                    self.assertIn("synthetic connection failure", result.stderr)
                    self.assertIn(f"{alias} ({codespace})", result.stderr)
                    invocation = json.loads(call.read_text())
                    self.assertEqual(invocation["prompt"], "1")
                    self.assertEqual(
                        invocation["args"],
                        [
                            "codespace", "ssh", "--codespace", codespace, "--",
                            "-T", "-i", str(Path(env["HOME"]) / ".ssh/codespaces.auto"),
                            "-o", "BatchMode=yes", "-o", "ConnectTimeout=30",
                            "-o", "ServerAliveInterval=30",
                            "-o", "ServerAliveCountMax=3", "exec sleep infinity",
                        ],
                    )
            env["GH_EXIT"] = "0"
            result = subprocess.run(
                ["bash", os.environ["keepAliveSource"], "cs1"],
                env=env, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn("ended unexpectedly", result.stderr)
            call.unlink()
            for alias in ("aci1", "missing"):
                result = subprocess.run(
                    ["bash", os.environ["keepAliveSource"], alias],
                    env=env, capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 1)
                self.assertIn("check the fleet registry", result.stderr)
                self.assertFalse(call.exists())
            invalid_registry = root / "invalid-registry.json"
            env["MSFT_FLEET_FILE"] = str(invalid_registry)
            for entry in (
                {"kind": "ssh", "data": {"name": "not-a-codespace"}},
                {"kind": "unknown", "data": {"name": "not-a-codespace"}},
                {"kind": "codespace", "data": {}},
            ):
                invalid_registry.write_text(json.dumps({"cs1": entry}))
                result = subprocess.run(
                    ["bash", os.environ["keepAliveSource"], "cs1"],
                    env=env, capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 1)
                self.assertFalse(call.exists())
            env["MSFT_FLEET_FILE"] = str(root / "missing-registry.json")
            result = subprocess.run(
                ["bash", os.environ["keepAliveSource"], "cs1"],
                env=env, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("check the fleet registry", result.stderr)
            self.assertFalse(call.exists())

    def test_packaged_keepalive_usage(self):
        result = subprocess.run(
            [str(Path(os.environ["keepAlive"]) / "bin/codespace-keepalive")],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 64)
        self.assertIn("Usage: codespace-keepalive", result.stderr)

    def test_ssh_aliases(self):
        expected = {
            "cs1": ("cs1", "root", "magical-unicorn-workspace"),
            "cs2": ("cs2", "root", "second-codespace"),
            "aci1": ("example.invalid", "root", None),
            "server": ("server.example.invalid", None, None),
        }
        for alias, (hostname, user, codespace) in expected.items():
            with self.subTest(alias=alias):
                result = subprocess.run(
                    ["ssh", "-G", "-F", os.environ["sshConfig"], alias],
                    capture_output=True, text=True, check=True,
                )
                options = dict(
                    line.split(" ", 1) for line in result.stdout.splitlines()
                )
                self.assertEqual(options["hostname"], hostname)
                if user is not None:
                    self.assertEqual(options["user"], user)
                if codespace is not None:
                    self.assertIn(f"--codespace {codespace}", options["proxycommand"])
                    self.assertIn("--stdio", options["proxycommand"])
                    self.assertEqual(options["stricthostkeychecking"], "false")
                else:
                    self.assertNotIn("proxycommand", options)

    def test_install_include(self):
        installer = (
            Path(os.environ["installSSHInclude"])
            / "bin/install-msft-fleet-ssh-test"
        )
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            ssh = home / ".ssh"
            ssh.mkdir()
            config = ssh / "config"
            original = "Host existing\n  HostName existing.example.invalid\n"
            config.write_text(original)
            env = dict(os.environ, HOME=directory)
            for _ in range(2):
                subprocess.run([installer], env=env, check=True)
                self.assertEqual(
                    config.read_text(),
                    "Include ~/.ssh/msft-fleet.conf\n\n" + original,
                )
            self.assertEqual(config.stat().st_mode & 0o777, 0o600)
            config.unlink()
            subprocess.run([installer], env=env, check=True)
            self.assertEqual(
                config.read_text(), "Include ~/.ssh/msft-fleet.conf\n\n",
            )
            scoped = "Host existing\n  Include ~/.ssh/msft-fleet.conf\n"
            config.write_text(scoped)
            subprocess.run([installer], env=env, check=True)
            self.assertEqual(
                config.read_text(), "Include ~/.ssh/msft-fleet.conf\n\n" + scoped,
            )
            config.unlink()
            target = home / "managed-config"
            target.write_text(original)
            config.symlink_to(target)
            result = subprocess.run([installer], env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("symlink", result.stderr)
            self.assertEqual(target.read_text(), original)
            managed = "# Managed SSH configuration\nInclude ~/.ssh/msft-fleet.conf\n"
            target.write_text(managed)
            subprocess.run([installer], env=env, check=True)
            self.assertTrue(config.is_symlink())
            self.assertEqual(target.read_text(), managed)
            self.assertEqual(list(ssh.glob(".msft-fleet-config.*")), [])


if __name__ == "__main__":
    unittest.main()
