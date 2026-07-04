{ ... }: {
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraSetFlags = [
      "--accept-dns=true"
    ];
  };
}
