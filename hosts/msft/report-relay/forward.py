#!/usr/bin/env python3
"""Reconnect a report's reverse SSH forwarding while preserving its host port."""

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
    try:
        with socket.create_connection(("127.0.0.1", args.port), timeout=5):
            pass
    except OSError as error:
        parser.error(f"app is not listening on 127.0.0.1:{args.port}: {error}")

    allocated = None
    try:
        while True:
            if not config.is_file():
                print("error: relay credentials are missing; retrying in 5 seconds", file=sys.stderr)
                time.sleep(5)
                continue
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
                            raise RuntimeError("relay SSH connection failed")
                        if time.monotonic() >= deadline:
                            raise RuntimeError("timed out connecting to relay")
                        time.sleep(0.1)
                    forwarding = subprocess.run(
                        [
                            *ssh, "-O", "forward",
                            "-R", f"127.0.0.1:{allocated or 0}:127.0.0.1:{args.port}",
                            "report-host",
                        ],
                        capture_output=True, text=True, timeout=10,
                    )
                    if forwarding.returncode:
                        raise RuntimeError(f"cannot forward report: {forwarding.stderr.strip()}")
                    if allocated is None:
                        candidate = forwarding.stdout.strip()
                        if not candidate.isdecimal() or not 1 <= int(candidate) <= 65535:
                            raise RuntimeError(f"invalid allocated port: {candidate!r}")
                        allocated = candidate
                        print(f"http://localhost:{allocated}", flush=True)
                    else:
                        print(f"Report tunnel restored at http://localhost:{allocated}", file=sys.stderr)
                    status = master.wait()
                    raise RuntimeError(f"report tunnel disconnected (SSH status {status})")
                except (RuntimeError, subprocess.TimeoutExpired) as error:
                    print(f"error: {error}; retrying in 5 seconds", file=sys.stderr)
                finally:
                    if master.poll() is None:
                        master.terminate()
                        try:
                            master.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            master.kill()
                            master.wait()
            time.sleep(5)
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
