{ pkgs, ... }:
{
  home.packages = [
    (pkgs.callPackage ../codex-cli { })
  ];
}
