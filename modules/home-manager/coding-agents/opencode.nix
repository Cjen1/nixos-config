{ pkgs, ... }:
{
  imports = [
    (import ./install-skills.nix {
      agent = "opencode";
      target = ".config/opencode/skills";
    })
  ];

  home.packages = [
    (pkgs.callPackage ../opencode-cli { })
  ];
}
