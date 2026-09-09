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

To initialize the remote Azure Linux host, run:

```sh
./hosts/msft/bootstrap-remote.sh
```

The script installs Nix without an init service, clones this repository into `/root/nixos-config`, builds `./hosts/msft#homeConfigurations.remote.activationPackage`, and activates it as `root`. Override connection settings with the `MSFT_REMOTE_HOST`, `MSFT_REMOTE_PORT`, and `MSFT_REMOTE_IDENTITY` environment variables.

## Enable Copilot reporting over SSH

The MSFT configurations enable `codingAgents.copilot.wmuxHooks.enable` on both
the local and remote hosts. Apply Home Manager on the host that runs Copilot,
then restart Copilot to load `~/.copilot/hooks/wmux.json`. If a manually installed
file already occupies that path, back it up before activation.

The hooks send wmux status and notification sequences through the terminal.
Inside tmux, each hook enables passthrough for its pane and wraps the sequence.
No wmux credentials or SSH environment forwarding are required.
Keep the tmux pane visible in an attached SSH terminal. Detached sessions and
hidden tmux panes do not deliver these sequences to wmux.

To check delivery with an isolated tmux server:

```sh
python3 scripts/test-wmux-copilot-hooks.py
WMUX_HOOK_MANIFEST="$HOME/.copilot/hooks/wmux.json" python3 scripts/test-wmux-copilot-hooks.py
```

## Update dependencies

Update only one host's dependencies:

```sh
nix flake update --flake ./hosts/mercury
```

Jasper owns its Agenix declarations, recipients, and encrypted files under `hosts/jasper/secrets/`. Its flake also owns the restricted `custom-tooling` input, so evaluate it only where that Forgejo instance is reachable.
