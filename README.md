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

Run the offline bump-script checks with `python3 scripts/test-bump-npm-package.py`.
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
nix build --impure --file scripts/test-neovim-lean.nix --no-link
```
