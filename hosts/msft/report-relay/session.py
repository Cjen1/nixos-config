#!/usr/bin/env python3
"""Provision an ephemeral relay identity and run its owning SSH connection."""

import io
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tarfile
import tempfile

from authorize import process_identity


def main():
    state = Path(os.environ.get(
        "MSFT_REPORT_RELAY_STATE", str(Path.home() / ".local/state/msft-report-relay"),
    ))
    user = os.environ["MSFT_REPORT_RELAY_USER"]
    with tempfile.TemporaryDirectory(prefix="session-", dir=state / "sessions") as directory:
        session = Path(directory)
        (session / "owner.json").write_text(json.dumps({
            "pid": os.getpid(), "start": process_identity(os.getpid()),
        }))
        identity = session / "identity"
        subprocess.run(
            ["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(identity)],
            check=True,
        )
        config = f"""Host report-host
  HostName 127.0.0.1
  Port 5588
  User {user}
  IdentityFile ~/.config/msft-report-relay/identity
  UserKnownHostsFile ~/.config/msft-report-relay/known_hosts
  IdentitiesOnly yes
  StrictHostKeyChecking yes
  BatchMode yes
  ConnectTimeout 10
  ServerAliveInterval 30
  ServerAliveCountMax 3
  ExitOnForwardFailure yes
"""
        payload = io.BytesIO()
        with tarfile.open(fileobj=payload, mode="w") as archive:
            archive.add(identity, arcname="identity")
            for name, content in (
                ("config", config),
                ("known_hosts", f'[127.0.0.1]:5588 {(state / "host-key.pub").read_text().strip()}\n'),
            ):
                data = content.encode()
                info = tarfile.TarInfo(name)
                info.mode = 0o600
                info.size = len(data)
                archive.addfile(info, io.BytesIO(data))
        identity.unlink()
        connection = subprocess.Popen(sys.argv[1:], stdin=subprocess.PIPE)

        def stop(signum, _frame):
            connection.send_signal(signum)

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        try:
            connection.stdin.write(payload.getvalue())
            connection.stdin.flush()
            payload.close()
            # Open stdin keeps the remote cat alive until this connection ends.
            status = connection.wait()
            return status if status >= 0 else 128 - status
        except BrokenPipeError:
            connection.wait()
            print("error: SSH connection closed before relay credentials were delivered", file=sys.stderr)
            status = connection.returncode or 1
            return status if status >= 0 else 128 - status
        finally:
            connection.stdin.close()
            if connection.poll() is None:
                connection.terminate()
                try:
                    connection.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    connection.kill()
                    connection.wait()


if __name__ == "__main__":
    sys.exit(main())
