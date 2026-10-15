{
  config,
  isRemote,
  lib,
  pkgs,
  ...
}:
let
  fleet = config.msft.fleet;
  relayState = "${config.home.homeDirectory}/.local/state/msft-report-relay";
  relayConfig = pkgs.writeText "msft-report-relay-sshd-config" ''
    ListenAddress 127.0.0.1
    Port 2222
    HostKey ${relayState}/host-key
    # Azure Linux 4's OpenSSH 10.0p2 client fails mlkem768x25519 KEX against this sshd.
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
    AuthorizedKeysFile none
    # OpenSSH rejects command paths through the group-writable Nix store.
    AuthorizedKeysCommand /usr/bin/env ${pkgs.python3}/bin/python3 ${./report-relay}/authorize.py ${relayState}/sessions
    AuthorizedKeysCommandUser ${config.home.username}
    AllowUsers ${config.home.username}
    AuthenticationMethods publickey
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    UsePAM no
    PermitRootLogin no
    AllowTcpForwarding remote
    PermitListen 127.0.0.1:*
    PermitOpen none
    GatewayPorts no
    AllowAgentForwarding no
    X11Forwarding no
    PermitTTY no
    PermitTunnel no
    MaxSessions 0
    PidFile none
  '';
  fleetFile = pkgs.writeText "msft-fleet.json" (
    builtins.toJSON (
      lib.mapAttrs (
        _: entry:
        if entry.codespace != null then
          {
            kind = "codespace";
            data.name = entry.codespace;
          }
        else
          {
            kind = "ssh";
            data.destination = entry.ssh;
          }
      ) fleet
    )
  );
  sshTarget = target: builtins.match "(([^[:space:]@]+)@)?([^[:space:]@]+)" target;
  sshConfig = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: entry:
      if entry.codespace != null then
        ''
          Host ${name}
            User root
            ProxyCommand ${pkgs.gh}/bin/gh codespace ssh --codespace ${lib.escapeShellArg entry.codespace} --stdio -- -i ${lib.escapeShellArg "${config.home.homeDirectory}/.ssh/codespaces.auto"}
            IdentityFile ~/.ssh/codespaces.auto
            UserKnownHostsFile /dev/null
            StrictHostKeyChecking no
            ServerAliveInterval 30
            ServerAliveCountMax 3
            ConnectTimeout 30
        ''
      else
        let
          target = sshTarget entry.ssh;
        in
        if target == null then
          throw "msft.fleet.${name}.ssh must be an OpenSSH destination: [user@]hostname."
        else
          ''
            Host ${name}
              HostName ${builtins.elemAt target 2}
            ${lib.optionalString (builtins.elemAt target 1 != null) "  User ${builtins.elemAt target 1}"}
          ''
    ) fleet
  );
  installSSHInclude = pkgs.writeShellApplication {
    name = "install-msft-fleet-ssh";
    runtimeInputs = [
      pkgs.coreutils
    ];
    text = builtins.readFile ./install-fleet-ssh.sh;
  };
  setupRelay = pkgs.writeShellApplication {
    name = "setup-msft-report-relay";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.openssh
      pkgs.util-linux
    ];
    text = ''
      export MSFT_REPORT_RELAY_STATE=${lib.escapeShellArg relayState}
    ''
    + builtins.readFile ./setup-report-relay.sh;
  };
  relaySession = pkgs.writeShellApplication {
    name = "msft-report-relay-session";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      export MSFT_REPORT_RELAY_STATE=${lib.escapeShellArg relayState}
      export MSFT_REPORT_RELAY_USER=${lib.escapeShellArg config.home.username}
      exec ${pkgs.python3}/bin/python3 ${./report-relay}/session.py "$@"
    '';
  };
  reportForward = pkgs.writeShellApplication {
    name = "msft-report-forward";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./report-relay}/forward.py "$@"
    '';
  };
  keepAlive = pkgs.writeShellApplication {
    name = "msft-fleet-keepalive";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gh
      pkgs.jq
      pkgs.openssh
      relaySession
    ];
    text = ''
      export MSFT_FLEET_FILE=${lib.escapeShellArg "${fleetFile}"}
    ''
    + builtins.readFile ./codespace-keepalive.sh;
  };
  syncEnvironment = pkgs.writeShellApplication {
    name = "sync-msft-remote-env";
    runtimeInputs = [ pkgs.openssh ];
    text = builtins.readFile ./sync-remote-env.sh;
  };
  bootstrap = pkgs.writeShellApplication {
    name = "msft-fleet-bootstrap";
    runtimeInputs = [
      pkgs.jq
      pkgs.openssh
      pkgs.gh
      syncEnvironment
    ];
    text = ''
      export MSFT_FLEET_FILE=${lib.escapeShellArg "${fleetFile}"}
      export MSFT_BOOTSTRAP_SCRIPT=${pkgs.writeText "bootstrap-nix-env.sh" (builtins.readFile ./bootstrap-nix-env.sh)}
    ''
    + builtins.readFile ./bootstrap-remote.sh;
  };
  update = pkgs.writeShellApplication {
    name = "msft-fleet-update";
    runtimeInputs = [
      pkgs.jq
      pkgs.openssh
      pkgs.gh
      syncEnvironment
    ];
    text = ''
      export MSFT_FLEET_FILE=${lib.escapeShellArg "${fleetFile}"}
      export MSFT_BOOTSTRAP_SCRIPT=${pkgs.writeText "bootstrap-nix-env.sh" (builtins.readFile ./bootstrap-nix-env.sh)}
    ''
    + builtins.readFile ./update-remote.sh;
  };
in
{
  options.msft.fleet = lib.mkOption {
    default = import ./fleet-registry.nix;
    description = "Named remote hosts, each with exactly one connection method.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          codespace = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Exact GitHub Codespace name. The CCF SSH image uses root.";
          };
          ssh = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "OpenSSH destination in [user@]hostname form.";
          };
        };
      }
    );
  };

  config = lib.mkMerge [
    {
      home.packages = lib.optionals isRemote [ reportForward ];
    }
    (lib.mkIf (!isRemote) {
      assertions = lib.mapAttrsToList (name: entry: {
        assertion =
          builtins.match "[A-Za-z0-9][A-Za-z0-9_-]*" name != null
          && ((entry.codespace != null) != (entry.ssh != null))
          && (entry.codespace == null || builtins.match "[A-Za-z0-9][A-Za-z0-9-]*" entry.codespace != null)
          && (entry.ssh == null || sshTarget entry.ssh != null);
        message = "msft.fleet.${name} must have a safe SSH alias and exactly one valid codespace or ssh destination.";
      }) fleet;

      home.sessionVariables.MSFT_FLEET_FILE = "${fleetFile}";
      home.packages = [
        bootstrap
        update
        keepAlive
        pkgs.gh
        pkgs.openssh
      ];
      home.file.".ssh/msft-fleet.conf".text = sshConfig;
      home.activation.installFleetSSHInclude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${installSSHInclude}/bin/install-msft-fleet-ssh
      '';
      home.activation.setupReportRelay = lib.mkIf (fleet != { }) (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${setupRelay}/bin/setup-msft-report-relay
        ''
      );
      systemd.user.services =
        lib.optionalAttrs (fleet != { }) {
          msft-report-relay = {
            Unit.Description = "Loopback-only SSH relay for fleet reports";
            Service = {
              ExecStartPre = "${setupRelay}/bin/setup-msft-report-relay";
              ExecStart = "${pkgs.openssh}/bin/sshd -D -e -f ${relayConfig}";
              Restart = "on-failure";
              RestartSec = "5s";
              UMask = "0077";
            };
            Install.WantedBy = [ "default.target" ];
          };
        }
        // lib.mapAttrs' (
          name: entry:
          lib.nameValuePair
            (if entry.codespace != null then "codespace-keepalive-${name}" else "fleet-report-tunnel-${name}")
            {
              Unit = {
                Description = "Keep fleet connection and report return tunnel for ${name} running";
                Wants = [ "msft-report-relay.service" ];
                After = [
                  "gnome-keyring.service"
                  "msft-report-relay.service"
                ];
                StartLimitIntervalSec = 0;
              };
              Service = {
                ExecStart = "${keepAlive}/bin/msft-fleet-keepalive ${name}";
                Restart = "always";
                RestartSec = "60s";
                TimeoutStopSec = "15s";
                KillMode = "control-group";
              }
              // lib.optionalAttrs (entry.codespace != null) {
                RuntimeMaxSec = "12h";
              };
              Install.WantedBy = [ "default.target" ];
            }
        ) fleet;
    })
  ];
}
