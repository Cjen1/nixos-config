#!/usr/bin/env python3
"""Exercise real nested SSH forwarding and ephemeral relay authorization."""

import http.client
import http.server
import io
import json
import os
from pathlib import Path
import pwd
import select
import shlex
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request


def free_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


class SessionTests(unittest.TestCase):
    def test_fresh_keys_cleanup_and_exit_status(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / "state"
            env = dict(
                os.environ, MSFT_REPORT_RELAY_STATE=str(state),
                MSFT_REPORT_RELAY_USER="fixture", PYTHONDONTWRITEBYTECODE="1",
            )
            subprocess.run(["bash", os.environ["setupRelaySource"]], env=env, check=True)
            scripts = Path(os.environ["relayScripts"])
            identities = []
            for _ in range(2):
                result = subprocess.run(
                    [
                        sys.executable, str(scripts / "session.py"),
                        sys.executable, "-c",
                        "import io, sys, tarfile\n"
                        "payload = io.BytesIO()\n"
                        "with tarfile.open(fileobj=sys.stdin.buffer, mode='r|') as incoming:\n"
                        " with tarfile.open(fileobj=payload, mode='w') as outgoing:\n"
                        "  for member in incoming:\n"
                        "   outgoing.addfile(member, incoming.extractfile(member))\n"
                        "sys.stdout.buffer.write(payload.getvalue())\n"
                        "sys.exit(7)\n",
                    ],
                    env=env, capture_output=True,
                )
                self.assertEqual(result.returncode, 7, result.stderr)
                with tarfile.open(fileobj=io.BytesIO(result.stdout)) as archive:
                    self.assertEqual(set(archive.getnames()), {"identity", "known_hosts", "config"})
                    identities.append(archive.extractfile("identity").read())
                    for member in archive:
                        self.assertEqual(member.mode, 0o600)
                self.assertEqual(list((state / "sessions").iterdir()), [])
            self.assertNotEqual(identities[0], identities[1])


class RelayTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.state = self.root / "state"
        self.user = pwd.getpwuid(os.getuid()).pw_name
        self.env = dict(
            os.environ, MSFT_REPORT_RELAY_STATE=str(self.state),
            MSFT_REPORT_RELAY_USER=self.user, PYTHONDONTWRITEBYTECODE="1",
        )
        self.scripts = Path(os.environ["relayScripts"])
        subprocess.run(["bash", os.environ["setupRelaySource"]], env=self.env, check=True)
        self.relay_port = free_port()
        config = Path(os.environ["relayConfig"]).read_text()
        config = config.replace("/home/fixture/.local/state/msft-report-relay", str(self.state))
        config = config.replace(" fixture", f" {self.user}")
        config = config.replace("Port 2222", f"Port {self.relay_port}")
        # Nix build users can be root in local, unsandboxed tests.
        config = config.replace("PermitRootLogin no", "PermitRootLogin prohibit-password")
        self.relay = self.daemon("relay", config)

    def daemon(self, name, config):
        path = self.root / f"{name}.conf"
        path.write_text(config)
        log = (self.root / f"{name}.log").open("w+")
        self.addCleanup(log.close)
        process = subprocess.Popen([shutil.which("sshd"), "-D", "-e", "-f", str(path)], stderr=log)
        self.addCleanup(self.stop, process)
        port = int(next(line.split()[1] for line in config.splitlines() if line.startswith("Port ")))
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if process.poll() is not None:
                log.seek(0)
                self.fail(log.read())
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                    return process
            except (ConnectionRefusedError, TimeoutError):
                time.sleep(0.05)
        self.fail(f"{name} did not start")

    @staticmethod
    def stop(process):
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        for stream in (process.stdin, process.stdout, process.stderr):
            if stream is not None:
                stream.close()

    def helper(self, port, home):
        process = subprocess.Popen(
            [str(Path(os.environ["reportForward"]) / "bin/msft-report-forward"), str(port)],
            env=dict(self.env, HOME=str(home)),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        self.addCleanup(self.stop, process)
        return process

    def ssh(self, directory):
        return [
            "ssh", "-F", "/dev/null", "-p", str(self.relay_port),
            "-i", str(directory / "identity"),
            "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=yes",
            "-o", f"UserKnownHostsFile={directory / 'known_hosts'}",
            "-o", "ConnectTimeout=5",
        ]

    def capture_session(self):
        home = self.root / "credentials"
        home.mkdir()
        capture = self.root / "capture.py"
        capture.write_text(
            "import os, sys, tarfile, time\n"
            "parent = os.getppid()\n"
            f"with tarfile.open(fileobj=sys.stdin.buffer, mode='r|') as archive:\n"
            f" archive.extractall({str(home)!r}, filter='data')\n"
            "while os.getppid() == parent: time.sleep(0.1)\n"
        )
        process = subprocess.Popen(
            [sys.executable, str(self.scripts / "session.py"), sys.executable, str(capture)],
            env=self.env,
        )
        self.addCleanup(self.stop, process)
        deadline = time.monotonic() + 10
        while not (home / "known_hosts").exists():
            self.assertIsNone(process.poll(), "credential session failed")
            self.assertLess(time.monotonic(), deadline)
            time.sleep(0.05)
        (home / "known_hosts").write_text(
            f"[127.0.0.1]:{self.relay_port} {(self.state / 'host-key.pub').read_text()}"
        )
        return process, home

    def test_setup_is_idempotent(self):
        original = (self.state / "host-key").read_bytes()
        subprocess.run(["bash", os.environ["setupRelaySource"]], env=self.env, check=True)
        self.assertEqual((self.state / "host-key").read_bytes(), original)
        self.assertEqual((self.state / "host-key").stat().st_mode & 0o777, 0o600)

    def test_restricted_ephemeral_authorization(self):
        owner, credentials = self.capture_session()
        ssh = self.ssh(credentials)
        destination = f"{self.user}@127.0.0.1"
        shell = subprocess.run([*ssh, destination, "true"], capture_output=True, text=True)
        self.assertNotEqual(shell.returncode, 0)
        self.assertIn("no more sessions", (self.root / "relay.log").read_text())
        local = subprocess.run(
            [*ssh, "-W", "127.0.0.1:2222", destination], capture_output=True, text=True,
        )
        self.assertNotEqual(local.returncode, 0)
        self.assertIn("administratively prohibited", local.stderr)
        wildcard = subprocess.run(
            [
                *ssh, "-N", "-o", "ExitOnForwardFailure=yes",
                "-R", "0.0.0.0:0:127.0.0.1:8765", destination,
            ],
            capture_output=True, text=True,
        )
        self.assertNotEqual(wildcard.returncode, 0)
        self.assertIn("remote port forwarding failed", wildcard.stderr)
        session = next((self.state / "sessions").iterdir())
        self.assertFalse((session / "identity").exists())
        owner_file = session / "owner.json"
        original_owner = owner_file.read_text()
        changed_owner = json.loads(original_owner)
        changed_owner["start"] = "wrong-process-start-time"
        owner_file.write_text(json.dumps(changed_owner))
        reused_pid = subprocess.run(
            [*ssh, destination, "true"], capture_output=True, text=True,
        )
        self.assertIn("Permission denied (publickey)", reused_pid.stderr)
        owner_file.write_text(original_owner)
        stale_key = credentials.joinpath("identity").read_bytes()
        owner.kill()
        owner.wait()
        denied = subprocess.run(
            [*ssh, destination, "true"], capture_output=True, text=True,
        )
        self.assertIn("Permission denied (publickey)", denied.stderr)
        self.assertEqual(credentials.joinpath("identity").read_bytes(), stale_key)
        authorized = subprocess.run(
            [sys.executable, str(self.scripts / "authorize.py"), str(self.state / "sessions")],
            check=True, capture_output=True, text=True,
        )
        self.assertEqual(authorized.stdout, "")

    def test_concurrent_nested_report_tunnels(self):
        operator_key = self.root / "operator"
        subprocess.run(
            ["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(operator_key)],
            check=True,
        )
        remote_port = free_port()
        self.daemon("remote", f"""
ListenAddress 127.0.0.1
Port {remote_port}
HostKey {self.state}/host-key
AuthorizedKeysFile {operator_key}.pub
AuthenticationMethods publickey
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM no
AllowUsers {self.user}
PermitRootLogin prohibit-password
StrictModes no
PidFile none
""")
        def connect(home, return_port):
            credentials = home / ".config/msft-report-relay"
            credentials.mkdir(parents=True, exist_ok=True)
            previous = (credentials / "identity").read_bytes() if (credentials / "identity").exists() else None
            ready = credentials / "ready"
            ready.unlink(missing_ok=True)
            remote_command = f"""bash -c {shlex.quote(
                f'set -e; umask 077; tar -xf - -C {shlex.quote(str(credentials))}; '
                f'touch {shlex.quote(str(ready))}; exec cat >/dev/null'
            )}"""
            outer = subprocess.Popen(
                [
                    sys.executable, str(self.scripts / "session.py"),
                    "ssh", "-F", "/dev/null", "-T", "-p", str(remote_port),
                    "-i", str(operator_key), "-o", "IdentitiesOnly=yes",
                    "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
                    "-o", "ExitOnForwardFailure=yes",
                    "-R", f"127.0.0.1:{return_port}:127.0.0.1:{self.relay_port}",
                    f"{self.user}@127.0.0.1", remote_command,
                ], env=self.env, stderr=subprocess.PIPE, text=True,
            )
            self.addCleanup(self.stop, outer)
            deadline = time.monotonic() + 10
            while (
                not ready.exists()
                or (credentials / "identity").read_bytes() == previous
            ):
                if outer.poll() is not None:
                    self.fail(f"{outer.stderr.read()}\n{(self.root / 'remote.log').read_text()}")
                self.assertLess(time.monotonic(), deadline)
                time.sleep(0.05)
            config = (credentials / "config").read_text()
            config = config.replace("Port 5588", f"Port {return_port}")
            config = config.replace("~/.config/msft-report-relay", str(credentials))
            (credentials / "config").write_text(config)
            known_hosts = (credentials / "known_hosts").read_text().replace(":5588", f":{return_port}")
            (credentials / "known_hosts").write_text(known_hosts)
            return outer, credentials

        results = []
        for index in range(2):
            home = self.root / f"remote-{index}"
            return_port = free_port()
            report_dir = home / "reports"
            report_dir.mkdir(parents=True)
            for name in ("first", "second"):
                (report_dir / f"{name}.html").write_text(f"node {index}: {name}")
            handler = lambda *args, directory=str(report_dir), **kwargs: http.server.SimpleHTTPRequestHandler(
                *args, directory=directory, **kwargs,
            )
            server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
            self.addCleanup(server.server_close)
            self.addCleanup(server.shutdown)
            threading.Thread(target=server.serve_forever, daemon=True).start()
            helper = self.helper(server.server_port, home)
            time.sleep(0.3)
            self.assertIsNone(helper.poll(), "report helper exited while waiting for credentials")
            outer, credentials = connect(home, return_port)
            readable, _, _ = select.select([helper.stdout], [], [], 15)
            self.assertTrue(readable, "forward helper did not return a URL")
            url = helper.stdout.readline().strip()
            if not url:
                self.fail(helper.stderr.read())
            self.assertRegex(url, r"^http://localhost:[0-9]+$")
            results.append((helper, outer, credentials, url, return_port))
        self.assertNotEqual(results[0][3], results[1][3])
        self.assertNotEqual(
            results[0][2].joinpath("identity").read_bytes(),
            results[1][2].joinpath("identity").read_bytes(),
        )
        for index, (_, _, _, url, _) in enumerate(results):
            for name in ("first", "second"):
                with urllib.request.urlopen(f"{url}/{name}.html", timeout=5) as response:
                    self.assertEqual(response.read().decode(), f"node {index}: {name}")
        helper, outer, credentials, url, return_port = results[0]
        for attempt in range(2):
            previous = (credentials / "identity").read_bytes()
            self.stop(outer)
            time.sleep(0.3)
            self.assertIsNone(helper.poll(), "report helper exited instead of reconnecting")
            blocker = None
            if attempt == 0:
                blocker = socket.socket()
                self.addCleanup(blocker.close)
                blocker.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                blocker.bind(("127.0.0.1", int(url.rsplit(":", 1)[1])))
                blocker.listen()
            outer, credentials = connect(credentials.parent.parent, return_port)
            self.assertNotEqual((credentials / "identity").read_bytes(), previous)
            if blocker is not None:
                errors = b""
                deadline = time.monotonic() + 15
                while b"cannot forward report" not in errors:
                    self.assertIsNone(helper.poll(), "report helper exited when its port was occupied")
                    remaining = deadline - time.monotonic()
                    self.assertGreater(remaining, 0, errors.decode())
                    readable, _, _ = select.select([helper.stderr], [], [], remaining)
                    self.assertTrue(readable, errors.decode())
                    errors += os.read(helper.stderr.fileno(), 4096)
                blocker.close()
            deadline = time.monotonic() + 20
            while True:
                self.assertIsNone(helper.poll(), "report helper exited during credential rotation")
                try:
                    with urllib.request.urlopen(f"{url}/first.html", timeout=1) as response:
                        self.assertEqual(response.read().decode(), "node 0: first")
                    break
                except (urllib.error.URLError, http.client.RemoteDisconnected, ConnectionResetError, TimeoutError):
                    self.assertLess(time.monotonic(), deadline, "original report URL was not restored")
                    time.sleep(0.1)
        with urllib.request.urlopen(f"{results[1][3]}/first.html", timeout=5) as response:
            self.assertEqual(response.read().decode(), "node 1: first")
        self.stop(outer)
        time.sleep(0.3)
        self.assertIsNone(helper.poll(), "report helper exited instead of waiting to reconnect")
        helper.terminate()
        self.assertEqual(helper.wait(timeout=5), 143)
        self.assertEqual(helper.stdout.read(), "", "reconnection should preserve the original URL")
        self.stop(results[1][0])
        self.assertEqual(results[1][0].returncode, 143)
        with self.assertRaises(urllib.error.URLError):
            urllib.request.urlopen(f"{results[1][3]}/first.html", timeout=5)


if __name__ == "__main__":
    unittest.main()
