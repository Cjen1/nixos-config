{ pkgs, ... }:
let
  appDir = "/data/tasks/ps-todos/ps-todos";
  dataDir = "/data/tasks/ps-todos/mnt";
in {
  systemd.services.ps-todos = {
    description = "PS Todos";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    path = with pkgs; [
      nodejs
      pnpm
    ];

    serviceConfig = {
      Type = "simple";
      User = "cjen1";
      WorkingDirectory = appDir;
      Environment = [
        "CONFIG=${dataDir}/config.json"
        "STORE=${dataDir}/amrg"
      ];
      ExecStart = pkgs.writeShellScript "ps-todos-start" ''
        set -euo pipefail

        pnpm install --frozen-lockfile
        pnpm --dir server_automerge install --frozen-lockfile
        pnpm run build

        cd server_automerge
        exec node server.js "$CONFIG" "$STORE"
      '';
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
