{
  config,
  isRemote,
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
    username = if isRemote then "root" else "cjen1-msft";
    homeDirectory = if isRemote then "/root" else "/home/cjen1-msft";
    sessionVariables = {
      LANG = "en_US.UTF-8";
      LC_CTYPE = "en_US.UTF-8";
    };
    packages = lib.optionals (!isRemote) [
      codespaceKeepAlive
      pkgs.nix
    ];
  };

  nix = lib.mkIf (!isRemote) {
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
      if [ -r "$HOME/.env" ]; then
        set -a
        . "$HOME/.env"
        set +a
      fi
    '';
  };

  programs.fish.shellInit = lib.mkBefore ''
    fish_add_path --prepend "$HOME/.nix-profile/bin"
    if test -r "$HOME/.env"
      for line in (grep -v '^#' "$HOME/.env" | grep -v '^$')
        set -gx (string split -m1 '=' $line)
      end
    end
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

  systemd.user.services.dbus = lib.mkIf (!isRemote) {
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

  services.gnome-keyring = lib.mkIf (!isRemote) {
    enable = true;
    components = [ "secrets" ];
  };

  systemd.user.services.gnome-keyring = lib.mkIf (!isRemote) {
    Unit = {
      Requires = [ "dbus.service" ];
      After = [ "dbus.service" ];
    };
    Service.Environment = [ "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus" ];
    Install.WantedBy = lib.mkAfter [ "default.target" ];
  };

  programs.home-manager.enable = true;

  codingAgents.copilot.wmuxHooks.enable = true;
  codingAgents.copilot.wmuxHooks.attentionExtension = "notify";

  codingAgents.copilot.instructionsSlug =
    if isRemote then
      ''
        # Host machine

        - This is a remote Azure Linux 3 machine reached over SSH. Nix is installed without an init service because the machine runs `/pause` as PID 1.
        - Use `nix shell nixpkgs#<tool>` or `nix run` for one-off tools rather than installing them globally.
        - Do not assume that WSL, `explorer.exe`, `wslpath`, or a local Windows browser is available.
        - The repository is at `/root/nixos-config`.
        - Link to this workspace with `<a href="vscode://vscode-remote/ssh-remote+20.91.249.202/root/nixos-config">workspace</a>`.
      ''
    else
      ''
        # Host machine

        - This is an Azure Linux 3 machine with nix installed. Reach for a `nix shell nixpkgs#<tool>` or `nix run` for one-off tools rather than installing them globally.
        - To open a generated HTML document in the Windows browser, convert its path first: `explorer.exe "$(wslpath -w file.html)"`. A bare WSL path won't resolve.
        - To make a file clickable from HTML or a browser into the editor, use `vscode://vscode-remote/wsl+AzureLinux3.0/<absolute-path>:<line>:<col>`. There is no `file/` segment in the WSL remote form. It opens the file at that line in the most recently active VS Code window, launching one if none is open. `vscode://file/...` and `vscodium://` do not work here.
        - Link to this workspace with `<a href="vscode://vscode-remote/wsl+AzureLinux3.0/home/cjen1-msft/">workspace</a>`.
      '';

  home.activation.setLoginShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    fish_path="$HOME/.nix-profile/bin/fish"
    current_shell="$(${pkgs.getent}/bin/getent passwd "${config.home.username}" | ${pkgs.coreutils}/bin/cut -d: -f7)"
    sudo_bin="$(PATH=/usr/bin:/bin command -v sudo || true)"
    chsh_bin="$(PATH=/usr/bin:/bin command -v chsh || true)"

    if [ "$current_shell" != "$fish_path" ]; then
      if [ "$(${pkgs.coreutils}/bin/id -u)" -eq 0 ]; then
        run_as_root() { "$@"; }
      elif [ -n "$sudo_bin" ] && "$sudo_bin" -n true 2>/dev/null; then
        run_as_root() { "$sudo_bin" -n "$@"; }
      else
        echo "warning: passwordless sudo is required to set the login shell to $fish_path" >&2
      fi

      if command -v run_as_root >/dev/null 2>&1 && [ -z "$chsh_bin" ]; then
        echo "error: chsh is required to set the login shell to $fish_path" >&2
        exit 1
      elif command -v run_as_root >/dev/null 2>&1; then
        if ! ${pkgs.gnugrep}/bin/grep -Fqx "$fish_path" /etc/shells; then
          printf '%s\n' "$fish_path" | run_as_root ${pkgs.coreutils}/bin/tee -a /etc/shells >/dev/null
        fi
        run_as_root "$chsh_bin" -s "$fish_path" "${config.home.username}"
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
