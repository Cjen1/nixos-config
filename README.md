# Nix configurations

Each machine owns an independent flake and lock file under `hosts/`. Shared NixOS and Home Manager modules live under `modules/` and are imported explicitly by each host.

| Host | Configuration | CI build |
| --- | --- | --- |
| `graphite` | NixOS with embedded Home Manager | Yes |
| `mercury` | NixOS with embedded Home Manager | Yes |
| `hematite` | NixOS with embedded Home Manager | No |
| `jasper` | NixOS with embedded Home Manager | No |
| `shale` | NixOS with embedded Home Manager | No |
| `msft` | Standalone Home Manager | No |

## Build and activate

For a NixOS host:

```sh
nix build ./hosts/mercury#nixosConfigurations.mercury.config.system.build.toplevel
sudo nixos-rebuild switch --flake ./hosts/mercury#mercury
```

For MSFT Home Manager:

```sh
nix build ./hosts/msft#homeConfigurations.cjen1-msft.activationPackage
home-manager switch --flake ./hosts/msft
```

## MSFT remote fleet

Declare named remote hosts in `hosts/msft/fleet-registry.nix`. The registry starts
empty. Each entry must contain exactly one connection method:

```nix
{
  cs1 = { codespace = "magical-unicorn-workspace"; };
  server1 = { ssh = "root@example-host"; };
}
```

Apply the laptop's Home Manager configuration after changing the registry.
It generates SSH aliases, so `ssh cs1` connects through GitHub CLI and
`ssh server1` uses ordinary SSH. Codespace aliases use `root`, matching CCF's
SSH devcontainer. The activation adds a top-level include to `~/.ssh/config`
without replacing its existing host definitions. If another configuration
manager owns that file through a symlink, add `Include ~/.ssh/msft-fleet.conf`
at the top through that manager instead.

`MSFT_FLEET_FILE` points to the generated JSON registry. Entries are tagged
variants: `{"kind":"codespace","data":{"name":"..."}}` or
`{"kind":"ssh","data":{"destination":"root@example-host"}}`, with no unused
transport fields. The Nix registry keeps the shorthand shown above.
Authenticate GitHub CLI
on the laptop with `gh auth login --scopes codespace`. The services use
those saved credentials, not variables sourced by an interactive shell.

After registering a new CCF SSH Codespace and applying Home Manager, run:

```sh
msft-fleet-bootstrap cs1
```

The command uses the registered SSH alias, which also starts stopped Codespaces.
It requires root login and preinstalled Git and curl. It installs Nix only when
absent, without an init service, and clones `Cjen1/nixos-config` branch `main`
into `/root/nixos-config`. It builds and activates the remote Home Manager
configuration, including Copilot's assisted permission default.

Remote activation also links the managed Copilot instructions and skills into
`/workspaces/.copilotd/state/copilot-home/` for copilotd.
It leaves the daemon's runtime home, sessions, and authentication unchanged,
and fails rather than replacing an unexpected file or symlink at that path.
After activation, start a fresh copilotd session to load the instructions and skills.

Remote activation also patches the local
`/workspaces/CCF/.devcontainer/azurelinux4-copilotd/start_copilotd.sh`, when present,
to source a Home Manager-managed Nix environment before starting the daemon.
The patch is repeatable and leaves a local modification in the CCF checkout;
it does not change the shared devcontainer configuration or restart running sessions.
It takes effect at the next daemon startup. If the launcher is replaced, rerun
bootstrap or update to reapply the patch. Non-Nix hosts are unaffected.

Bootstrap and update copy the laptop's `~/.env`, if present, to `/root/.env`
after activation. The copy atomically replaces the remote file with mode `0600`;
new remote shells load its variables, including any PAT. A missing local file
leaves the remote file untouched. Copy failures fail that host's operation.
Credentials travel over SSH and are never stored in the Nix store.

Rerunning bootstrap fast-forwards a clean `main` checkout to `origin/main`.
It refuses dirty checkouts (including untracked files), local-only commits,
other branches, unexpected repository origins, and non-checkout directories.
SSH failures and installation, build, or activation failures return nonzero
with error context; correct the reported problem and rerun. Generic SSH entries
use the same command but must also provide a root Azure Linux environment.

Codespace rebuilds can erase `/root` and `/nix`; rerun bootstrap after a rebuild.
This does not restore interrupted Copilot sessions.

Home Manager installs `msft-fleet-bootstrap`, `msft-fleet-update`, and
`msft-fleet-keepalive` in the laptop's `PATH`. Update all registered hosts, or
select aliases:

```sh
msft-fleet-update
msft-fleet-update cs1 server1
```

Update assumes bootstrap is complete: it never installs Nix or clones a missing
checkout. It fast-forwards and activates `origin/main` with the same checkout
protections as bootstrap. Stopped Codespaces start through the SSH proxy.
Updates run sequentially and continue after host failures, then return nonzero
with the failed aliases. Invalid aliases are rejected before any host is updated.
Empty fleets are a no-op. Connections use a 30-second connect timeout and detect
unresponsive peers through SSH keepalives; builds have no overall time limit.

Each Codespace gets a laptop-only user service named
`codespace-keepalive-<alias>.service`. It holds a GitHub CLI SSH command open so
the CLI sends activity heartbeats, automatically starts stopped Codespaces,
and retries failed connections after 60 seconds. Ordinary SSH entries get a
`fleet-report-tunnel-<alias>.service` instead. Home Manager starts added services and stops removed ones;
remove an entry and apply the configuration to end management.
The service runs `msft-fleet-keepalive <alias>`; there is no need to launch a
separate keepalive process manually.

The services require the laptop's Linux environment and user systemd manager
to remain running. GitHub's 12-hour runtime limit still applies. Reconnection
does not restore Copilot, tmux sessions, or other interrupted processes.
Inspect a service with:

```sh
systemctl --user status codespace-keepalive-cs1.service
journalctl --user -u codespace-keepalive-cs1.service
```

### Remote HTML reports

With a nonempty fleet, Home Manager also runs `msft-report-relay.service`: an
unprivileged SSH server bound only to `127.0.0.1:2222`. Each managed fleet
connection forwards the node's `127.0.0.1:5588` back to that server. Interactive
SSH connections do not own or duplicate these tunnels. Both ports must be free
on their respective machines; forwarding failures are logged and retried.

On a bootstrapped remote, start an HTTP server serving only the report directory,
then start the forwarding helper in another terminal or persistent background
process:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory /path/to/reports
msft-report-forward 8765
```

The helper prints `http://localhost:<allocated-host-port>`. Append the report's
relative path and open the URL in the host's browser. One server can serve many
reports; multiple nodes or helpers get distinct host ports automatically.
Keep both processes running while viewing, and stop them afterward. If a
managed connection disconnects, its report helpers exit nonzero; rerun them
after reconnection and use their new URLs. Without a running host user manager,
the relay is unavailable.

Every managed connection generates a fresh Ed25519 client key and delivers it
and the pinned relay host key over the existing authenticated fleet SSH
connection. Remote credentials are installed with mode `0600` under
`~/.config/msft-report-relay`. The host deletes its temporary private key after
preparing the credential payload. Authorization checks the supervising process's
PID and Linux start time, so leftover keys are rejected after a crash or PID
reuse. Keys permit only loopback reverse forwarding: no shell, commands, local
forwarding, agent forwarding, or public listeners. No personal SSH keys are
copied or agents forwarded.

The stable relay host key lives in `~/.local/state/msft-report-relay`, not the
Nix store. Applying Home Manager does not rotate it. Removing a fleet entry
stops its managed connection and invalidates its session key. This is not a
security boundary against a compromised remote's own administrator, who can
read that node's live relay credential and use its permitted forwarding.
The host must provide a root-owned `/usr/bin/env`; OpenSSH uses it to launch
the pinned Nix authorization helper because it rejects command paths through
the group-writable Nix store.

Inspect the relay with `journalctl --user -u msft-report-relay.service`.
Run the registry, bootstrap/update, mocked keepalive, and ephemeral-key checks:

```sh
nix build --impure --file tests/test-msft-fleet.nix --no-link
```

Exercise real concurrent nested SSH forwarding and denied access on the host:

```sh
nix-shell tests/test-msft-fleet.nix --run 'python3 tests/test-msft-report-relay.py'
```

These live checks run outside the build sandbox because its `nixbld` account
has no login shell. They use temporary SSH servers and keys, not fleet nodes.

## Copilot permissions

The shared Copilot Nix module sets `defaultPermissionMode` to `assisted` during
Home Manager activation. Remote bootstrap already runs that activation, so it
needs no separate settings step. Copilot's settings command preserves other
user preferences.

This default applies to new interactive sessions, not resumed sessions.
Assisted approval reviews tool requests and may still ask for permission.
It does not grant unrestricted access.

Check settings preservation and repeat activation with
`python3 tests/test-copilot-settings.py`.

## Copilot notifications in wmux

The MSFT configuration enables status hooks and the experimental `wmux-attention`
extension. Apply Home Manager on the machine running Copilot, then restart
Copilot. Over SSH, keep the tmux pane visible and attached.

On first load, approve the extension's request for permission-event access.
The handler always returns no decision, leaving approval to Copilot.

Permission alerts wait 1.5 seconds and cancel if the request resolves first.
Slow automatic approvals can still alert. The extension does not change
permission decisions.

If the extension fails or you want the original permission alerts, set
`codingAgents.copilot.wmuxHooks.attentionExtension = "off"` in
`hosts/msft/home.nix`, apply Home Manager, and restart Copilot.

## Update dependencies

Update only one host's dependencies:

```sh
nix flake update --flake ./hosts/mercury
```

To update a packaged coding agent, run its `bump.sh` with a version or omit the
version for `latest`:

```sh
./modules/home-manager/github-copilot-cli/bump.sh
./modules/home-manager/codex-cli/bump.sh 0.151.0
./modules/home-manager/opencode-cli/bump.sh
./hosts/msft/claude-code/bump.sh
```

The scripts update the npm manifests and Nix hash without building the package.
They use Mercury's pinned nixpkgs, reuse matching dependencies from the previous
Nix cache, and download only missing tarballs. If the previous cache is absent,
they fetch all dependencies. A lockfile that matches the cached copy retains its
hash without prefetching.

To also verify the full package build, add `--build`. The build reuses the
prefetched cache:

```sh
./modules/home-manager/github-copilot-cli/bump.sh --build
```

Run the offline bump-script checks with `python3 tests/test-bump-npm-package.py`.
Use `--integration` to compare a merged cache against the pinned prefetcher and
verify the full build. Use `--benchmark <baseline-revision>` to compare repeat
Codex bumps against an earlier Git revision. These two modes use temporary
package copies and download dependencies.

Jasper owns its Agenix declarations, recipients, and encrypted files under `hosts/jasper/secrets/`. Its flake also owns the restricted `custom-tooling` input, so evaluate it only where that Forgejo instance is reachable.

## Lean 4 in Neovim

The shared Neovim configuration, also available as `vim`, includes a pinned
[Lean 4 Tree-sitter grammar](https://github.com/Julian/tree-sitter-lean) for
highlighting and folding `.lean` files. The static grammar cannot fully parse
user-defined Lean syntax. This does not install a Lean language server.

After changing the grammar, run the integration check from the repository root:

```sh
nix build --impure --file tests/test-neovim-lean.nix --no-link
```
