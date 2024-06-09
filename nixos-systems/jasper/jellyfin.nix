{pkgs, ...}:{
  environment.systemPackages = with pkgs; [
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
  ];
  services.jellyfin = {
    enable = true;
    user = "cjen1";
    cacheDir = "/data/jellyfin/cache";
    configDir = "/data/jellyfin/config";
    dataDir = "/data/jellyfin/data";
  };
}
