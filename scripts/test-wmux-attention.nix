let
  flake = builtins.getFlake (toString ../hosts/msft);
  config =
    mode: remote:
    (flake.inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs.isRemote = remote;
      modules = [
        ../hosts/msft/home.nix
        { codingAgents.copilot.wmuxHooks.attentionExtension = mode; }
      ];
    }).config;
  manifest =
    c: builtins.fromJSON (builtins.unsafeDiscardStringContext c.home.file.".copilot/hooks/wmux.json".text);
  matcher = c: (builtins.head (manifest c).hooks.notification).matcher;
  off = config "off" true;
  observe = config "observe" true;
  notify = config "notify" true;
  local = config "notify" false;
in
assert matcher off == "permission_prompt|elicitation_dialog";
assert matcher observe == matcher off;
assert matcher notify == "elicitation_dialog";
assert matcher local == matcher notify;
assert builtins.attrNames (manifest off).hooks == builtins.attrNames (manifest notify).hooks;
assert !(off.home.file ? ".copilot/extensions/wmux-attention");
[
  observe.home.file.".copilot/extensions/wmux-attention".source
  notify.home.file.".copilot/extensions/wmux-attention".source
  notify.home.file.".copilot/hooks/wmux.json".source
]
