{
  config,
  isRemote,
  lib,
  pkgs,
  ...
}:
let
  fleet = config.msft.fleet;
  codespaces = lib.filterAttrs (_: entry: entry.codespace != null) fleet;
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
  keepAlive = pkgs.writeShellApplication {
    name = "msft-fleet-keepalive";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gh
      pkgs.jq
      pkgs.openssh
    ];
    text =
      ''
        export MSFT_FLEET_FILE=${lib.escapeShellArg "${fleetFile}"}
      ''
      + builtins.readFile ./codespace-keepalive.sh;
  };
  bootstrap = pkgs.writeShellApplication {
    name = "msft-fleet-bootstrap";
    runtimeInputs = [
      pkgs.jq
      pkgs.openssh
      pkgs.gh
    ];
    text =
      ''
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
    ];
    text =
      ''
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

  config = lib.mkIf (!isRemote) {
    assertions = lib.mapAttrsToList (name: entry: {
      assertion =
        builtins.match "[A-Za-z0-9][A-Za-z0-9_-]*" name != null
        && ((entry.codespace != null) != (entry.ssh != null))
        && (
          entry.codespace == null
          || builtins.match "[A-Za-z0-9][A-Za-z0-9-]*" entry.codespace != null
        )
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
    systemd.user.services = lib.mapAttrs' (
      name: _:
      lib.nameValuePair "codespace-keepalive-${name}" {
        Unit = {
          Description = "Keep registered Codespace ${name} running";
          After = [ "gnome-keyring.service" ];
          StartLimitIntervalSec = 0;
        };
        Service = {
          ExecStart = "${keepAlive}/bin/msft-fleet-keepalive ${name}";
          Restart = "always";
          RestartSec = "60s";
          RuntimeMaxSec = "12h";
          TimeoutStopSec = "15s";
          KillMode = "control-group";
        };
        Install.WantedBy = [ "default.target" ];
      }
    ) codespaces;
  };
}
