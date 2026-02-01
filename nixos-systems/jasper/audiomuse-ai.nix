{config, ...}:{
  imports = [
    ../../modules/nixos/docker-services
    ../../secrets
  ];

  virtualisation.arion.projects."audiomuse-ai".settings = {
    services."audiomuse-redis".service = {
      image = "redis:7-alpine";
      restart = "unless-stopped";
      volumes = [
        "/data/audiomuse-ai/redis:/data"
      ];
    };

    services."audiomuse-postgres".service = {
      image = "postgres:15-alpine";
      restart = "unless-stopped";
      environment = {
        POSTGRES_USER = "audiomuse";
        POSTGRES_PASSWORD = "audiomuse";
        POSTGRES_DB = "audiomusedb";
      };
      volumes = [
        "/data/audiomuse-ai/postgres:/var/lib/postgresql/data"
      ];
      healthcheck = {
        test = ["CMD-SHELL" "pg_isready --dbname=audiomusedb --username=audiomuse"];
        start_period = "20s";
        interval = "30s";
      };
    };

    services."audiomuse-flask".service = {
      image = "ghcr.io/neptunehub/audiomuse-ai:latest";
      restart = "unless-stopped";
      env_file = [ config.age.secrets."audiomuse-jellyfin-token".path ];
      environment = {
        SERVICE_TYPE = "flask";
        MEDIASERVER_TYPE = "jellyfin";
        JELLYFIN_URL = "http://host.docker.internal:8096";
        JELLYFIN_USER_ID = "cjen1";
        POSTGRES_HOST = "audiomuse-postgres";
        POSTGRES_USER = "audiomuse";
        POSTGRES_PASSWORD = "audiomuse";
        POSTGRES_DB = "audiomusedb";
        POSTGRES_PORT = "5432";
        REDIS_URL = "redis://audiomuse-redis:6379/0";
        AI_MODEL_PROVIDER = "NONE";
        CLAP_ENABLED = "true";
        TZ = "UTC";
      };
      volumes = [
        "/data/audiomuse-ai/temp-audio-flask:/app/temp_audio"
      ];
      ports = ["8000:8000"];
      depends_on = ["audiomuse-redis" "audiomuse-postgres"];
    };

    services."audiomuse-worker".service = {
      image = "ghcr.io/neptunehub/audiomuse-ai:latest";
      restart = "unless-stopped";
      env_file = [ config.age.secrets."audiomuse-jellyfin-token".path ];
      environment = {
        SERVICE_TYPE = "worker";
        MEDIASERVER_TYPE = "jellyfin";
        JELLYFIN_URL = "http://host.docker.internal:8096";
        JELLYFIN_USER_ID = "cjen1";
        POSTGRES_HOST = "audiomuse-postgres";
        POSTGRES_USER = "audiomuse";
        POSTGRES_PASSWORD = "audiomuse";
        POSTGRES_DB = "audiomusedb";
        POSTGRES_PORT = "5432";
        REDIS_URL = "redis://audiomuse-redis:6379/0";
        AI_MODEL_PROVIDER = "NONE";
        CLAP_ENABLED = "true";
        TZ = "UTC";
      };
      volumes = [
        "/data/audiomuse-ai/temp-audio-worker:/app/temp_audio"
      ];
      depends_on = ["audiomuse-redis" "audiomuse-postgres"];
    };
  };

  services.caddy.virtualHosts."audiomuse.jentek.dev".extraConfig = ''
    reverse_proxy 127.0.0.1:8000
  '';
}
