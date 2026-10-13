#!/usr/bin/env python3
"""Authorize only keys belonging to a live fleet connection supervisor."""

import json
from pathlib import Path
import sys


def process_identity(pid):
    try:
        stat = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
    except FileNotFoundError:
        return None
    if stat[0] == "Z":
        return None
    return stat[19]


def main():
    for session in sorted(Path(sys.argv[1]).glob("session-*")):
        try:
            owner = json.loads((session / "owner.json").read_text())
            key = (session / "identity.pub").read_text().strip()
        except FileNotFoundError:
            continue
        if process_identity(owner["pid"]) == owner["start"]:
            print(f'restrict,port-forwarding,permitlisten="127.0.0.1:*" {key}')


if __name__ == "__main__":
    main()
