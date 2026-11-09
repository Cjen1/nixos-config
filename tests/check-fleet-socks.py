#!/usr/bin/env python3
"""Verify a fleet reverse SOCKS tunnel against a local-only SSH-banner probe."""

import argparse
import json
import os
import secrets
import socketserver
import subprocess
import threading


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("host", help="SSH fleet alias running the reverse SOCKS listener")
    parser.add_argument("--port", type=int, default=1080, help="remote SOCKS port")
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("--port must be between 1 and 65535")
    banner = f"SSH-2.0-fleet-proxy-{secrets.token_hex(16)}\r\n".encode()
    challenge = secrets.token_bytes(32)

    class Probe(socketserver.BaseRequestHandler):
        def handle(self):
            self.request.settimeout(10)
            self.request.sendall(banner)
            remaining = len(challenge)
            while remaining:
                data = self.request.recv(remaining)
                if not data:
                    raise ConnectionError("Proxy closed before the challenge was received")
                remaining -= len(data)
                self.request.sendall(data)

    with socketserver.ThreadingTCPServer(("127.0.0.1", 0), Probe) as server:
        server.daemon_threads = True
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        configuration = {
            "port": args.port,
            "destination": server.server_address[1],
            "banner": banner.hex(),
            "challenge": challenge.hex(),
        }
        remote = f"configuration = {configuration!r}\n" + '''
import socket
import struct
from pathlib import Path

listeners = []
for table in ("tcp", "tcp6"):
    for line in Path("/proc/net", table).read_text().splitlines()[1:]:
        fields = line.split()
        address, port = fields[1].split(":")
        if fields[3] == "0A" and int(port, 16) == configuration["port"]:
            listeners.append(address)
assert listeners == ["0100007F"], f"Expected an IPv4 loopback-only listener, got {listeners}"

def receive(connection, count):
    result = b""
    while len(result) < count:
        data = connection.recv(count - len(result))
        if not data:
            raise ConnectionError("Proxy closed before the response was received")
        result += data
    return result

for address in (b"\\x01\\x7f\\x00\\x00\\x01", b"\\x03\\x09localhost"):
    with socket.create_connection(("127.0.0.1", configuration["port"]), timeout=10) as connection:
        connection.sendall(b"\\x05\\x01\\x00")
        assert receive(connection, 2) == b"\\x05\\x00", "SOCKS negotiation failed"
        connection.sendall(b"\\x05\\x01\\x00" + address + struct.pack("!H", configuration["destination"]))
        response = receive(connection, 4)
        assert response[:3] == b"\\x05\\x00\\x00", f"SOCKS connect failed: {response.hex()}"
        if response[3] == 1:
            length = 4
        elif response[3] == 4:
            length = 16
        elif response[3] == 3:
            length = receive(connection, 1)[0]
        else:
            raise ValueError(f"Unknown SOCKS address type: {response[3]}")
        receive(connection, length + 2)
        banner = bytes.fromhex(configuration["banner"])
        assert receive(connection, len(banner)) == banner, "Did not reach the local SSH-banner probe"
        challenge = bytes.fromhex(configuration["challenge"])
        connection.sendall(challenge)
        assert receive(connection, len(challenge)) == challenge, "Bidirectional byte forwarding failed"
print("PASS: loopback-only SOCKS; IPv4 and hostname targets reach the local probe; binary traffic works both ways")
'''
        try:
            subprocess.run(
                [
                    "ssh", "-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=15",
                    "--", args.host, "python3 -",
                ],
                input=remote, text=True, check=True, timeout=45,
                env={
                    key: value for key, value in os.environ.items()
                    if key not in ("GH_TOKEN", "GITHUB_TOKEN")
                },
            )
        finally:
            server.shutdown()
            thread.join()
    print(json.dumps({"host": args.host, "socks_port": args.port, "status": "healthy"}))


if __name__ == "__main__":
    main()
