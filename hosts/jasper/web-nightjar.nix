{ inputs, ... }:
{
  # The pinned release embeds the app, worklets and WASM; players supply their IPA locally.
  systemd.tmpfiles.rules = [
    "d /srv/nightjar 0755 root root -"
    # Kept outside the public web root and the Nix store.
    "d /srv/nightjar-ipa 0755 root root -"
    "L+ /srv/nightjar/index.html - - - - ${inputs.web-nightjar}/release/nightjar.html"
  ];

  services.caddy.virtualHosts."web-nightjar.jentek.dev".extraConfig = ''
    root * /srv/nightjar
    encode zstd gzip
    header {
      Cache-Control "no-cache"
      X-Content-Type-Options "nosniff"
      Referrer-Policy "no-referrer"
    }
    file_server
  '';
}
