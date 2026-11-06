{ pkgs, ... }:

let
  dataDir = "/data/persist/home-assistant";
  initialConfiguration = pkgs.writeText "home-assistant-configuration.yaml" ''
    default_config:

    automation: !include automations.yaml
    script: !include scripts.yaml
    scene: !include scenes.yaml

    http:
      use_x_forwarded_for: true
      trusted_proxies:
        - 127.0.0.1
        - "::1"
  '';
in
{
  imports = [
    ../../modules/nixos/docker-services
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;
  };

  virtualisation.arion.projects."home-assistant".settings = {
    services."home-assistant".service = {
      image = "ghcr.io/home-assistant/home-assistant:2026.8.2";
      restart = "unless-stopped";
      network_mode = "host";
      capabilities = {
        NET_ADMIN = true;
        NET_RAW = true;
      };
      environment.TZ = "Europe/London";
      volumes = [
        "${dataDir}:/config"
        "/run/dbus:/run/dbus:ro"
        "/etc/localtime:/etc/localtime:ro"
      ];
    };
  };

  systemd.services.home-assistant-storage-setup = {
    description = "Prepare Home Assistant storage";
    after = [ "zfs-mount.service" ];
    requires = [ "zfs-mount.service" ];
    before = [ "arion-home-assistant.service" ];
    unitConfig.ConditionPathIsMountPoint = "/data/persist";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.coreutils}/bin/install -d -m 0750 ${dataDir}

      if [ ! -e ${dataDir}/configuration.yaml ]; then
        ${pkgs.coreutils}/bin/install -m 0640 ${initialConfiguration} ${dataDir}/configuration.yaml
      fi

      ${pkgs.coreutils}/bin/touch \
        ${dataDir}/automations.yaml \
        ${dataDir}/scripts.yaml \
        ${dataDir}/scenes.yaml
      ${pkgs.coreutils}/bin/chmod 0640 \
        ${dataDir}/automations.yaml \
        ${dataDir}/scripts.yaml \
        ${dataDir}/scenes.yaml
    '';
  };

  systemd.services.arion-home-assistant = {
    after = [
      "bluetooth.service"
      "home-assistant-storage-setup.service"
    ];
    requires = [
      "bluetooth.service"
      "home-assistant-storage-setup.service"
    ];
  };
}
