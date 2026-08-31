{ pkgs, ... }:
{
  imports = [
    (import ./install-skills.nix {
      agent = "codex";
      target = ".codex/skills";
    })
  ];

  home.packages = [
    (pkgs.callPackage ../codex-cli { })
  ];
}
