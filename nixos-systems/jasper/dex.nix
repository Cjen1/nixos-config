{ config, lib, pkgs, ... }:
let
  dexPasswordHash = config.age.secrets."dex-password-hash".path;
in {
  imports = [
    ../../secrets
  ];

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "dex" ];
    ensureUsers = [
      {
        name = "dex";
        ensureDBOwnership = true;
      }
    ];
  };

  services.dex = {
    enable = true;
    settings = {
      issuer = "https://oidc.jentek.dev";
      storage = {
        type = "postgres";
        config.host = "/var/run/postgresql";
      };
      web.http = "127.0.0.1:5556";
      oauth2.skipApprovalScreen = true;
      enablePasswordDB = true;

      staticClients = [
        {
          id = "tailscale";
          name = "Tailscale";
          redirectURIs = [ "https://login.tailscale.com/a/oauth_response" ];
          secretFile = config.age.secrets."dex-tailscale-client-secret".path;
        }
      ];

      staticPasswords = [
        {
          email = "cjen1@jentek.dev";
          username = "cjen1";
          userID = "cjen1";
          hash = dexPasswordHash;
        }
      ];
    };
  };

  systemd.services.dex.serviceConfig.ExecStartPre = lib.mkAfter [
    "+${pkgs.replace-secret}/bin/replace-secret '${dexPasswordHash}' '${dexPasswordHash}' /run/dex/config.yaml"
  ];

  services.caddy.virtualHosts."jentek.dev".extraConfig = ''
    @webfinger path /.well-known/webfinger

    handle @webfinger {
      header Content-Type application/jrd+json
      respond `{
        "subject": "acct:cjen1@jentek.dev",
        "links": [
          {
            "rel": "http://openid.net/specs/connect/1.0/issuer",
            "href": "https://oidc.jentek.dev"
          }
        ]
      }`
    }

    handle {
      redir https://www.jentek.dev{uri} permanent
    }
  '';

  services.caddy.virtualHosts."oidc.jentek.dev".extraConfig = ''
    reverse_proxy 127.0.0.1:5556
  '';
}
