#!/usr/bin/env python3
"""Check OSC delivery through a controlling terminal and an isolated tmux server."""

import base64
import errno
import json
import os
from pathlib import Path
import pty
import select
import shlex
import subprocess
import tempfile
import time


def read_until(fd, expected):
    output = b""
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if select.select([fd], [], [], 0.1)[0]:
            try:
                chunk = os.read(fd, 65536)
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                break
            if not chunk:
                break
            output += chunk
            if expected in output:
                return
    raise AssertionError(f"Expected terminal bytes {expected!r}; received {output!r}")


def terminal(command, env):
    pid, fd = pty.fork()
    if pid == 0:
        os.execvpe(command[0], command, env)
    return pid, fd


def main():
    env = dict(os.environ, TERM="xterm-256color")
    for key in ("TMUX", "TMUX_PANE", "WMUX_TTY_PATH"):
        env.pop(key, None)
    manifest_path = os.environ.get("WMUX_HOOK_MANIFEST")
    if manifest_path:
        manifest = json.loads(Path(manifest_path).read_text())
        events = {
            "userPromptSubmitted", "preToolUse", "agentStop", "subagentStart",
            "subagentStop", "notification", "errorOccurred", "sessionEnd",
        }
        assert manifest["version"] == 1
        assert set(manifest["hooks"]) == events
        command = manifest["hooks"]["agentStop"][0]["bash"]
        assert manifest["hooks"]["notification"][0]["matcher"] == (
            "permission_prompt|elicitation_dialog"
        )
    else:
        hook = Path(__file__).resolve().parents[1] / (
            "modules/home-manager/coding-agents/wmux-copilot-hook.sh"
        )
        command = f"bash {shlex.quote(str(hook))} agentStop"

    payload = '{"sessionId":"wmux-transport-test"}'
    expected = (
        b"\x1b]777;wmux;copilot;agentStop;"
        + base64.b64encode(payload.encode())
        + b"\x07"
    )
    command = f"printf %s {shlex.quote(payload)} | {command}"
    pid, fd = terminal(["bash", "-c", command], env)
    try:
        read_until(fd, expected)
    finally:
        _, status = os.waitpid(pid, 0)
        os.close(fd)
    assert os.waitstatus_to_exitcode(status) == 0
    print("PASS: direct controlling terminal")

    with tempfile.TemporaryDirectory(prefix="wmux-tmux-test-") as directory:
        tmux = ["tmux", "-S", str(Path(directory) / "socket")]

        def run(*args):
            return subprocess.check_output(
                [*tmux, *args], env=env, stderr=subprocess.PIPE, text=True
            ).strip()

        run("-f", "/dev/null", "new-session", "-d", "-s", "test",
            "-x", "80", "-y", "24", "bash --noprofile --norc")
        pid = fd = None
        try:
            run("set-option", "-g", "allow-passthrough", "off")
            pid, fd = terminal([*tmux, "attach-session", "-t", "test"], env)
            deadline = time.monotonic() + 10
            while not run("list-clients"):
                if time.monotonic() >= deadline:
                    raise AssertionError("tmux client did not attach")
                time.sleep(0.05)
            run("send-keys", "-t", "test:0.0", "-l", command)
            run("send-keys", "-t", "test:0.0", "Enter")
            read_until(fd, expected)
            assert run("show-options", "-p", "-v", "-t", "test:0.0",
                       "allow-passthrough") == "on"
            print("PASS: tmux starts with passthrough off; hook enables it and OSC reaches client")
        finally:
            run("kill-server")
            if fd is not None:
                os.close(fd)
            if pid is not None:
                os.waitpid(pid, 0)


if __name__ == "__main__":
    main()
