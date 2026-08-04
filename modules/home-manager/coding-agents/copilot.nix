{ pkgs, ... }:
{
  home.packages = [
    (pkgs.callPackage ../github-copilot-cli { })
  ];
}
