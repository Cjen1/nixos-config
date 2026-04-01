{ lib, pkgs, ... }:
{
  programs.ssh.package = lib.mkDefault (pkgs.openssh.override {
    withKerberos = true;
  });
}
