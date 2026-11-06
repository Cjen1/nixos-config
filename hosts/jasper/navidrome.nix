{ pkgs, inputs, ... }:
let
  audiomusePlugin = pkgs.stdenvNoCC.mkDerivation {
    pname = "audiomuseai";
    version = "9.0.0";
    src = pkgs.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI-NV-plugin/releases/download/v9/audiomuseai.ndp";
      hash = "sha256-vKC4SrKTWfNkpkX7qWjEV0ubyB71jG8z0DlXrjO1DPw=";
    };
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm0444 "$src" "$out/share/plugins/audiomuseai.ndp"
      runHook postInstall
    '';
    passthru.isNavidromePlugin = true;
    meta = {
      description = "AudioMuse-AI sonic similarity plugin for Navidrome";
      homepage = "https://github.com/NeptuneHub/AudioMuse-AI-NV-plugin";
      license = pkgs.lib.licenses.agpl3Only;
    };
  };
in
{
  services.navidrome = {
    enable = true;
    package = inputs.nixpkgs-navidrome.legacyPackages.${pkgs.stdenv.hostPlatform.system}.navidrome.withPlugins (_: [ audiomusePlugin ]);
    openFirewall = false;
    settings = {
      # AudioMuse runs in Docker and reaches Navidrome through the host gateway.
      # Port 4533 remains closed by the host firewall; Caddy is the public entrypoint.
      Address = "0.0.0.0";
      Port = 4533;
      Agents = "audiomuseai,deezer,lastfm,listenbrainz";
      MusicFolder = "/data/media/music_clean/music";
      DataFolder = "/data/navidrome/data";
      CacheFolder = "/data/navidrome/cache";
      PlaylistsPath = "/etc/navidrome/playlists";
      Scanner.Schedule = "@every 1h";
      Plugins.AutoReload = true;
      Backup = {
        Path = "/data/navidrome/backups";
        Schedule = "0 3 * * *";
        Count = 7;
      };
    };
  };

  environment.etc = {
    "navidrome/playlists/recently-played.nsp".source = ./navidrome-playlists/recently-played.nsp;
    "navidrome/playlists/rediscover.nsp".source = ./navidrome-playlists/rediscover.nsp;
    "navidrome/playlists/unplayed-favourites.nsp".source = ./navidrome-playlists/unplayed-favourites.nsp;
  };

  systemd.services.navidrome-storage-setup = {
    description = "Prepare Navidrome storage";
    after = [ "zfs-mount.service" ];
    requires = [ "zfs-mount.service" ];
    before = [ "navidrome.service" ];
    unitConfig.ConditionPathIsMountPoint = "/data/navidrome";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/install -d -m 0700 -o navidrome -g navidrome /data/navidrome/data /data/navidrome/cache /data/navidrome/backups";
    };
  };

  systemd.services.navidrome = {
    after = [ "zfs-mount.service" "navidrome-storage-setup.service" ];
    requires = [ "zfs-mount.service" "navidrome-storage-setup.service" ];
    unitConfig.ConditionPathIsMountPoint = "/data/navidrome";
  };
}
