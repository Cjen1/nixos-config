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
  codespaceKeepAliveLoop = pkgs.writeShellScript "codespace-keepalive-loop" ''
    while true; do
      if ! ${pkgs.openssh}/bin/ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=30 \
        -o ServerAliveInterval=15 \
        -o ServerAliveCountMax=3 \
        ghcs1-raw \
        'printf "pong %s\n" "$(/bin/date --iso-8601=seconds)"'
      then
        printf 'Codespaces keep-alive failed at %s\n' \
          "$(${pkgs.coreutils}/bin/date --iso-8601=seconds)" >&2
      fi
      ${pkgs.coreutils}/bin/sleep 240
    done
  '';
  codespaceKeepAlive = pkgs.writeShellScriptBin "codespace-keepalive" ''
    session=codespace-keepalive-ghcs1
    if ! ${pkgs.tmux}/bin/tmux has-session -t "$session" 2>/dev/null; then
      if ! ${pkgs.tmux}/bin/tmux new-session -d -s "$session" ${codespaceKeepAliveLoop}; then
        printf 'Failed to start local Codespaces keep-alive session\n' >&2
      fi
    fi
  '';
in
{

  imports = [
    ../../modules/home-manager/tui.nix
    ../../modules/home-manager/excalidraw.nix
    ../../modules/home-manager/coding-agents/opencode.nix
    ../../modules/home-manager/coding-agents/codex.nix
    ../../modules/home-manager/coding-agents/copilot.nix
  ];

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = (_: true);
  };

  home = {
    username ="cjen1-msft";
    homeDirectory = "/home/cjen1-msft";
    sessionVariables = {
      LANG = "en_US.UTF-8";
      LC_CTYPE = "en_US.UTF-8";
    };
    packages = [
      codespaceKeepAlive
      pkgs.nix
    ];
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

  programs.fish.shellInit = lib.mkBefore ''
    fish_add_path --prepend "$HOME/.nix-profile/bin"
  '';

  programs.tmux = {
    enable = true;
    mouse = true;
    historyLimit = 200000;
    terminal = "xterm-256color";
    extraConfig = ''
      set -g extended-keys on
      set -g extended-keys-format csi-u
      set -as terminal-features ",xterm-256color:RGB"
      unbind-key -T root WheelUpPane
      unbind-key -T root MouseDrag1Pane
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

  programs.copilot-in-cc = {
    enable = true;
    service.enable = false;
    claudePackage = pkgs.callPackage ./claude-code { };
  };

  home.activation.setLoginShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    fish_path="$HOME/.nix-profile/bin/fish"
    current_shell="$(${pkgs.getent}/bin/getent passwd "$USER" | ${pkgs.coreutils}/bin/cut -d: -f7)"
    sudo_bin="$(PATH=/usr/bin:/bin command -v sudo || true)"
    chsh_bin="$(PATH=/usr/bin:/bin command -v chsh || true)"

    if [ "$current_shell" != "$fish_path" ]; then
      if [ -z "$sudo_bin" ] || ! "$sudo_bin" -n true 2>/dev/null; then
        echo "warning: passwordless sudo is required to set the login shell to $fish_path" >&2
      elif [ -z "$chsh_bin" ]; then
        echo "error: chsh is required to set the login shell to $fish_path" >&2
        exit 1
      else
        if ! ${pkgs.gnugrep}/bin/grep -Fqx "$fish_path" /etc/shells; then
          printf '%s\n' "$fish_path" | "$sudo_bin" -n ${pkgs.coreutils}/bin/tee -a /etc/shells >/dev/null
        fi
        "$sudo_bin" -n "$chsh_bin" -s "$fish_path" "$USER"
      fi
    fi
  '';

  home.file = {
    ".bash_profile".force = true;
    ".bashrc".force = true;
    ".profile".force = true;
    ".tmux.conf" = {
      force = true;
      text = ''
        source-file "$HOME/.config/tmux/tmux.conf"
      '';
    };
  };

  home.stateVersion = "24.11";
}
