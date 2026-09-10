#!/usr/bin/env python3
"""Run a built extension with synthetic SDK events through a real PTY and tmux."""

import base64
import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

spec = importlib.util.spec_from_file_location(
    "hook_transport", Path(__file__).with_name("test-wmux-copilot-hooks.py")
)
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)

build = Path(sys.argv[1])
config = (build / "config.mjs").read_text()
if "export const dryRun = false;" not in config:
    raise ValueError("Pass the notify-mode extension build")

with tempfile.TemporaryDirectory(prefix="wmux-attention-test-") as directory:
    root = Path(directory)
    for name in ("extension.mjs", "attention.mjs"):
        shutil.copyfile(build / name, root / name)
    (root / "config.mjs").write_text(config)
    (root / "sdk.mjs").write_text("""
export async function joinSession() {
    return {
        sessionId: "transport-test",
        on(callback) {
            setTimeout(() => {
                callback({
                    type: "permission.requested",
                    data: { requestId: "test-request" },
                });
            }, 0);
            setTimeout(() => process.exit(0), 1800);
            return () => {};
        },
        rpc: { permissions: { pendingRequests: async () => ({ items: [] }) } },
    };
}
""")
    (root / "loader.mjs").write_text("""
export async function resolve(specifier, context, nextResolve) {
    if (specifier === "@github/copilot-sdk/extension") {
        return { url: new URL("./sdk.mjs", import.meta.url).href, shortCircuit: true };
    }
    return nextResolve(specifier, context);
}
""")
    command = [
        "node", "--no-warnings", "--experimental-loader", str(root / "loader.mjs"),
        str(root / "extension.mjs"),
    ]
    payload = {
        "sessionId": "transport-test",
        "requestId": "test-request",
        "notificationType": "permission_prompt",
        "message": "Copilot has a pending permission request",
    }
    expected = (
        b"\x1b]777;wmux;copilot;notification;"
        + base64.b64encode(json.dumps(payload, separators=(",", ":")).encode())
        + b"\x07"
    )
    transport.check_transport(shlex.join(command), expected)

    (root / "config.mjs").write_text(
        config.replace("export const dryRun = false;", "export const dryRun = true;")
    )
    tty = root / "tty"
    tty.write_bytes(b"")
    env = dict(os.environ, WMUX_TTY_PATH=str(tty), TMUX="", TMUX_PANE="")
    result = subprocess.run(command, env=env, capture_output=True, check=True)
    assert b"dry-run notification test-request" in result.stderr
    assert tty.read_bytes() == b""
    print("PASS: observe mode receives the request but emits no OSC")
