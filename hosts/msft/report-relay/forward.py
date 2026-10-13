#!/usr/bin/env python3
"""Keep a report's dynamically allocated reverse SSH forwarding alive."""

import argparse
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time


def main():
    signal.signal(signal.SIGTERM, lambda signum, _frame: sys.exit(128 + signum))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", type=int, help="running HTTP server's loopback port")
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("port must be between 1 and 65535")
    config = Path.home() / ".config/msft-report-relay/config"
    if not config.is_file():
        parser.error("relay credentials are missing; reconnect the host's fleet tunnel")
    try:
        with socket.create_connection(("127.0.0.1", args.port), timeout=5):
            pass
    except OSError as error:
        parser.error(f"app is not listening on 127.0.0.1:{args.port}: {error}")

    with tempfile.TemporaryDirectory(prefix="msft-report-") as directory:
        control = Path(directory) / "ssh"
        ssh = ["ssh", "-F", str(config), "-S", str(control)]
        master = subprocess.Popen(
            [*ssh, "-M", "-N", "-T", "-o", "ControlPersist=no", "report-host"],
            stdin=subprocess.DEVNULL,
        )
        try:
            deadline = time.monotonic() + 30
            while not control.exists():
                if master.poll() is not None:
                    print("error: relay SSH connection failed", file=sys.stderr)
                    return 1
                if time.monotonic() >= deadline:
                    print("error: timed out connecting to relay", file=sys.stderr)
                    return 1
                time.sleep(0.1)
            forwarding = subprocess.run(
                [
                    *ssh, "-O", "forward",
                    "-R", f"127.0.0.1:0:127.0.0.1:{args.port}", "report-host",
                ],
                capture_output=True, text=True,
            )
            if forwarding.returncode:
                print(f"error: cannot forward report: {forwarding.stderr.strip()}", file=sys.stderr)
                return 1
            allocated = forwarding.stdout.strip()
            if not allocated.isdecimal() or not 1 <= int(allocated) <= 65535:
                print(f"error: invalid allocated port: {allocated!r}", file=sys.stderr)
                return 1
            print(f"http://localhost:{allocated}", flush=True)
            master.wait()
            print("error: report tunnel disconnected; rerun msft-report-forward", file=sys.stderr)
            return 1
        except KeyboardInterrupt:
            return 130
        finally:
            if master.poll() is None:
                master.terminate()
                try:
                    master.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    master.kill()
                    master.wait()


if __name__ == "__main__":
    sys.exit(main())
