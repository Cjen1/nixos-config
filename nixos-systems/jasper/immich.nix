{...}:{
  imports = [
    ../../modules/nixos/docker-services
  ];

  virtualisation.arion.projects."immich".settings = {
    services."immich-server".service = {
      image = "ghcr.io/immich-app/immich-server:release";
      restart = "unless-stopped";
      volumes = [
        "/data/media/immich/upload:/usr/src/app/upload"
        "/etc/localtime:/etc/localtime:ro"
      ];
      environment = {
        DB_HOSTNAME = "immich-postgres";
        DB_USERNAME = "postgres";
        DB_PASSWORD = "postgres";
        DB_DATABASE_NAME = "immich";
        REDIS_HOSTNAME = "immich-redis";
      };
      ports = ["2283:2283"];
      depends_on = ["immich-redis" "immich-postgres"];
    };

    services."immich-machine-learning".service = {
      image = "ghcr.io/immich-app/immich-machine-learning:release";
      restart = "unless-stopped";
      volumes = [
        "/data/media/immich/model-cache:/cache"
      ];
    };

    services."immich-redis".service = {
      image = "docker.io/valkey/valkey:8-alpine";
      restart = "unless-stopped";
      healthcheck = {
        test = ["CMD" "valkey-cli" "ping"];
        start_period = "20s";
        interval = "30s";
      };
    };

    services."immich-postgres".service = {
      image = "docker.io/tensorchord/pgvecto-rs:pg14-v0.3.0";
      restart = "unless-stopped";
      user = "1003:1003";
      environment = {
        POSTGRES_PASSWORD = "postgres";
        POSTGRES_USER = "postgres";
        POSTGRES_DB = "immich";
        POSTGRES_INITDB_ARGS = "--data-checksums";
      };
      volumes = [
        "/data/media/immich/postgres:/var/lib/postgresql/data"
      ];
      healthcheck = {
        test = ["CMD-SHELL" "pg_isready --dbname=immich --username=postgres"];
        start_period = "20s";
        interval = "30s";
      };
    };
  };

  services.caddy.virtualHosts."immich.jentek.dev".extraConfig = ''
    reverse_proxy 127.0.0.1:2283
  '';
}
