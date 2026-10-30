---
name: fleet-health
description: Check fleet health and repair unhealthy nodes. Optionally accepts a node name.
---

Check WSL and all nodes in `~/nixos-config/hosts/msft/fleet-registry.nix`,
or just the named node if supplied.

Check copilotd responsiveness and relay connectivity, not merely whether a
process exists. Fix unhealthy nodes using their existing launchers or
supervisors; leave healthy nodes alone. Restart WSL last as it may interrupt
this conversation.

Preserve sessions and other services. Do not upgrade daemons or reboot hosts.
Verify recovery and briefly report each node's status and any remaining blockers.
