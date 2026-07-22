{
  lib,
  pkgs,
  ...
}:
let
  dbusSessionConfig = pkgs.runCommand "dbus-session.conf" { } ''
    substitute ${pkgs.dbus}/share/dbus-1/session.conf "$out" \
      --replace-fail \
        '<standard_session_servicedirs />' \
        '<standard_session_servicedirs />
         <servicedir>${pkgs.gnome-keyring}/share/dbus-1/services</servicedir>
         <servicedir>${pkgs.gcr}/share/dbus-1/services</servicedir>'
  '';
in
{

  imports = [
    ../../modules/home-manager/tui.nix
    ../../modules/home-manager/excalidraw.nix
  ];

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = (_: true);
  };

  home = {
    username ="cjen1-msft";
    homeDirectory = "/home/cjen1-msft";
  };

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  programs.git.settings = {
    http.sslCAInfo = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    diff.tool = "vscode";
    difftool.vscode.cmd = "code --wait --diff \"$LOCAL\" \"$REMOTE\"";
  };

  programs.bash = {
    enable = true;
    bashrcExtra = ''
      if [ -r /etc/bash.bashrc ]; then
        . /etc/bash.bashrc
      fi
      if [ -r "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      fi
      if [ -r "$HOME/.profile" ]; then
        . "$HOME/.profile"
      fi
    '';
  };

  programs.neovim = {
    withPython3 = true;
    withRuby = true;
  };

  systemd.user.services.dbus = {
    Unit.Description = "D-Bus User Message Bus";
    Service = {
      ExecStart = "${pkgs.dbus}/bin/dbus-daemon --config-file=${dbusSessionConfig} --address=unix:path=%t/bus --nofork --nopidfile";
      Environment = [
        "DISPLAY=:0"
        "WAYLAND_DISPLAY=wayland-0"
      ];
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };

  services.gnome-keyring = {
    enable = true;
    components = [ "secrets" ];
  };

  systemd.user.services.gnome-keyring = {
    Unit = {
      Requires = [ "dbus.service" ];
      After = [ "dbus.service" ];
    };
    Service.Environment = [ "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus" ];
    Install.WantedBy = lib.mkAfter [ "default.target" ];
  };

  programs.home-manager.enable = true;

  home.file = {
    ".bash_profile".force = true;
    ".bashrc".force = true;
    ".profile".force = true;
  };

  home.stateVersion = "24.11";
}
