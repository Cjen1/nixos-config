{ config, pkgs, ... }:
{
  imports = [
    ../../secrets
  ];

  systemd.services.forgejo-secrets = {
    after = [ "zfs-mount.service" ];
    requires = [ "zfs-mount.service" ];
    unitConfig.ConditionPathIsMountPoint = "/data/forgejo";
  };

  systemd.services.forgejo = {
    after = [ "zfs-mount.service" ];
    requires = [ "zfs-mount.service" ];
    unitConfig.ConditionPathIsMountPoint = "/data/forgejo";
  };

  systemd.tmpfiles.rules = [
    "d /data/forgejo/custom 0750 forgejo forgejo -"
    "d /data/forgejo/custom/conf 0750 forgejo forgejo -"
  ];

  services.forgejo = {
    enable = true;
    database.type = "sqlite3";
    stateDir = "/data/forgejo";

    settings = {
      server = {
        DOMAIN = "forgejo.ts.jentek.dev";
        ROOT_URL = "https://forgejo.ts.jentek.dev/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;
      };

      actions.ENABLED = true;
      service.DISABLE_REGISTRATION = true;
    };
  };

  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.jasper = {
      enable = true;
      name = "jasper-runner";
      url = "https://forgejo.ts.jentek.dev/";

      tokenFile = config.age.secrets."forgejo-runner-token".path;

      labels = [
        "docker:docker://node:22-bookworm"
        "ubuntu-latest:docker://node:22-bookworm"
      ];
    };
  };

  virtualisation.docker.enable = true;
  networking.firewall.trustedInterfaces = [ "br-+" ];
}
