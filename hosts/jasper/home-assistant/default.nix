{ pkgs, ... }:

let
  dataDir = "/data/persist/home-assistant";
  # The query string changes with the file, so browsers fetch the new card.
  trendCardVersion = builtins.substring 0 12 (builtins.hashFile "sha256" ./www/trend-card.js);
  configuration = pkgs.writeText "home-assistant-configuration.yaml" ''
    default_config:

    automation: !include automations.yaml
    script: !include scripts.yaml
    scene: !include scenes.yaml

    http:
      use_x_forwarded_for: true
      trusted_proxies:
        - 127.0.0.1
        - "::1"

    frontend:
      themes: !include themes.yaml

    lovelace:
      dashboards:
        health-dash:
          mode: yaml
          filename: dashboards/health.yaml
          title: Health
          icon: mdi:paw
          show_in_sidebar: true
  '';
  # Custom cards must load as dashboard resources: extra_module_url runs before
  # the frontend swaps in its own custom-element registry, so cards defined
  # there are never found. HA keeps resources in its storage, so these are
  # merged in at start: Nix's entries replace any with the same id, and
  # resources added in the UI are kept.
  lovelaceResources = pkgs.writeText "lovelace_resources" (builtins.toJSON {
    version = 1;
    minor_version = 1;
    key = "lovelace_resources";
    data.items = [
      {
        id = "trend-card";
        url = "/local/trend-card.js?v=${trendCardVersion}";
        type = "module";
      }
    ];
  });
in
{
  imports = [
    ../../../modules/nixos/docker-services
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
        # Nix owns these; mounting them means a change restarts the container.
        "${configuration}:/config/configuration.yaml:ro"
        "${./themes.yaml}:/config/themes.yaml:ro"
        "${./dashboards}:/config/dashboards:ro"
        "${./www}:/config/www:ro"
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
      ${pkgs.coreutils}/bin/install -d -m 0750 ${dataDir} ${dataDir}/.storage

      res=${dataDir}/.storage/lovelace_resources
      if [ -e "$res" ]; then
        ${pkgs.jq}/bin/jq --slurpfile nix ${lovelaceResources} '
          ($nix[0].data.items | map(.id)) as $ids
          | .data.items = ([.data.items[] | select(.id as $id | $ids | index($id) | not)] + $nix[0].data.items)
        ' "$res" > "$res.tmp"
      else
        ${pkgs.coreutils}/bin/cp ${lovelaceResources} "$res.tmp"
      fi
      ${pkgs.coreutils}/bin/chmod 0644 "$res.tmp"
      ${pkgs.coreutils}/bin/mv "$res.tmp" "$res"

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
