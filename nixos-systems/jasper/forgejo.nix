{ config, pkgs, ... }:
let
  forgejoRunnerConfig = (pkgs.formats.yaml { }).generate "forgejo-runner-config.yaml" {
    server.connections.forgejo = {
      url = "https://forgejo.ts.jentek.dev/";
      uuid = "737ed90b-d611-4be3-92c3-36f5ba7b5f4d";
      token_url = "file:$CREDENTIALS_DIRECTORY/forgejo-runner-token";
      labels = [
        "docker:docker://node:22-bookworm"
        "ubuntu-latest:docker://node:22-bookworm"
      ];
    };
  };
in
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

  systemd.services.forgejo-runner-jasper = {
    description = "Forgejo Actions Runner";
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    environment.HOME = "/var/lib/forgejo-runner";

    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "forgejo-runner";
      WorkingDirectory = "-/var/lib/forgejo-runner";
      SupplementaryGroups = [ "docker" ];
      LoadCredential = [
        "forgejo-runner-token:${config.age.secrets."forgejo-runner-token".path}"
      ];
      ExecStart = "${pkgs.forgejo-runner}/bin/forgejo-runner daemon --config ${forgejoRunnerConfig}";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  virtualisation.docker.enable = true;
  networking.firewall.trustedInterfaces = [ "br-+" ];
}
