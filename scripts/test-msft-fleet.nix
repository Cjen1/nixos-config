let
  flake = builtins.getFlake (toString ../hosts/msft);
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  lib = pkgs.lib;
  configuration =
    remote: fleet:
    (flake.inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs.isRemote = remote;
      modules = [
        ../hosts/msft/fleet.nix
        {
          home.username = "fixture";
          home.homeDirectory = "/home/fixture";
          home.stateVersion = "24.11";
          msft.fleet = fleet;
        }
      ];
    }).config;
  sample = {
    cs1.codespace = "magical-unicorn-workspace";
    cs2.codespace = "second-codespace";
    aci1.ssh = "root@example.invalid";
    server.ssh = "server.example.invalid";
  };
  local = configuration false sample;
  empty = configuration false { };
  remote = configuration true sample;
  invalid = fleet: !(builtins.tryEval (configuration false fleet).home.homeDirectory).success;
  sshConfig = pkgs.writeText "fleet-ssh-config" local.home.file.".ssh/msft-fleet.conf".text;
  keepAlive = lib.findFirst (package: package.name == "codespace-keepalive") null local.home.packages;
  bootstrap = lib.findFirst (package: package.name == "bootstrap-codespace-nix-env") null local.home.packages;
in
assert !(remote.home.sessionVariables ? MSFT_FLEET_FILE);
assert !(remote.home.file ? ".ssh/msft-fleet.conf");
assert remote.systemd.user.services == { };
assert empty.home.file.".ssh/msft-fleet.conf".text == "";
assert empty.systemd.user.services == { };
assert builtins.attrNames local.systemd.user.services == [
  "codespace-keepalive-cs1"
  "codespace-keepalive-cs2"
];
assert local.systemd.user.services.codespace-keepalive-cs1.Service.Restart == "always";
assert local.systemd.user.services.codespace-keepalive-cs1.Service.RestartSec == "60s";
assert local.systemd.user.services.codespace-keepalive-cs1.Unit.StartLimitIntervalSec == 0;
assert local.systemd.user.services.codespace-keepalive-cs1.Install.WantedBy == [ "default.target" ];
assert lib.hasSuffix " cs1" (builtins.head local.systemd.user.services.codespace-keepalive-cs1.Service.ExecStart);
assert lib.hasSuffix " cs2" (builtins.head local.systemd.user.services.codespace-keepalive-cs2.Service.ExecStart);
assert invalid { bad = { }; };
assert invalid { bad = { codespace = "one"; ssh = "example.invalid"; }; };
assert invalid { "bad alias".codespace = "one"; };
assert invalid { bad.codespace = "one;echo"; };
assert invalid { bad.ssh = "root@host extra"; };
pkgs.runCommand "test-msft-fleet" {
  nativeBuildInputs = [
    pkgs.python3
    pkgs.openssh
    pkgs.jq
    pkgs.git
    pkgs.shellcheck
  ];
  inherit sshConfig keepAlive bootstrap;
  keepAliveSource = ../hosts/msft/codespace-keepalive.sh;
  bootstrapSource = ../hosts/msft/bootstrap-remote.sh;
  remoteBootstrap = ../hosts/msft/bootstrap-nix-env.sh;
  fleetFile = local.home.sessionVariables.MSFT_FLEET_FILE;
  installSSHInclude = pkgs.writeShellApplication {
    name = "install-msft-fleet-ssh-test";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ../hosts/msft/install-fleet-ssh.sh;
  };
} ''
  shellcheck -e SC1091 ${../hosts/msft/bootstrap-nix-env.sh}
  python3 ${./test-msft-fleet.py}
  python3 ${./test-msft-bootstrap.py}
  touch "$out"
''
