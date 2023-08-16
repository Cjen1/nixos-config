{pkgs,...}:
let 
desktop_item = name: direction: pkgs.makeDesktopItem {
  name = "ipsec-${direction}-${name}";
  desktopName = "VPN ${direction} ${name}";
  exec = "sudo ipsec ${direction} ${name}";
  terminal = true;
};
in {
  environment.systemPackages = [
    (desktop_item "CAM" "up")
    (desktop_item "CAM" "down")
    (desktop_item "CL" "up")
    (desktop_item "CL" "down")
  ];
}
