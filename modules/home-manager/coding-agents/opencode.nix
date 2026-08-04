{ pkgs, ... }:
{
  home.packages = [
    (pkgs.callPackage ../opencode-cli { })
  ];
}
