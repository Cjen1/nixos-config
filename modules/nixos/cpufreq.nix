{pkgs, ...}:
let
  set_gov = option: pkgs.makeDesktopItem {
    name = "cpufreq-gov-${option}";
    desktopName = "Set CPU to ${option}";
    exec = "sudo ${pkgs.cpupower}/bin/cpupower frequency-set -g ${option}";
    terminal = true;
  };
in {
  environment.systemPackages = [
    (set_gov "performance")
    (set_gov "powersave")
  ];
}
