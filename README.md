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

Update only one host's dependencies:

```sh
nix flake update --flake ./hosts/mercury
```

Jasper owns its Agenix declarations, recipients, and encrypted files under `hosts/jasper/secrets/`. Its flake also owns the restricted `custom-tooling` input, so evaluate it only where that Forgejo instance is reachable.
