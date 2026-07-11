{ pkgs, ... }:
{
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

      # Create this file after creating a runner token in Forgejo:
      #   /var/lib/forgejo-runner/token
      # The file must contain: TOKEN=<runner-token>
      tokenFile = "/var/lib/forgejo-runner/token";

      labels = [
        "docker:docker://node:22-bookworm"
        "ubuntu-latest:docker://node:22-bookworm"
      ];
    };
  };

  virtualisation.docker.enable = true;
  networking.firewall.trustedInterfaces = [ "br-+" ];
}
