{ config, ... }:
let
  url = "cache.r3dlust.com";
  s3Url = "s3.cache.r3dlust.com";
  bucket = "nix-cache-1";
in
{
  networking.certificates.${url} = {
    enable = true;
    group = "dns-certs";
    users = [
      "caddy"
    ];

    postRun = ''
      systemctl reload-or-restart caddy.service
    '';
  };

  networking.certificates.${s3Url} = {
    enable = true;
    group = "dns-certs";
    users = [ "caddy" ];
    postRun = ''
      systemctl reload-or-restart caddy.service
    '';
  };

  secrets = {
    cache-token = {
      owner = config.services.niks3.user;
      group = config.services.niks3.group;
      mode = "0400";
    };
    niks3-signing-key = {
      file = ./signing-key.age;
      owner = "niks3";
      group = "niks3";
      mode = "0400";
    };
    niks3-s3-access-key = {
      file = ./s3-access-key.age;
      owner = "niks3";
      group = "niks3";
      mode = "0400";
    };
    niks3-s3-secret-key = {
      file = ./s3-secret-key.age;
      owner = "niks3";
      group = "niks3";
      mode = "0400";
    };
  };

  services.niks3 = {
    enable = true;
    httpAddr = "127.0.0.1:25915";
    apiTokenFile = config.secrets.cache-token.path;
    signKeyFiles = [ config.secrets.niks3-signing-key.path ];

    s3 = {
      endpoint =  "http://lab:9000";
      inherit bucket;
      publicUrl = "https://${s3Url}";
      bucketLookup = "path";
      region = "us-east-1";
      useSSL = false;
      accessKeyFile = config.secrets.niks3-s3-access-key.path;
      secretKeyFile = config.secrets.niks3-s3-secret-key.path;
    };

    serverUrl = "https://${url}";
    cacheUrl = "https://${url}";
    readProxy.enable = true;

    nginx.enable = false;

    gc = {
      enable = true;
      olderThan = "168h";
      failedUploadsOlderThan = "6h";
      schedule = "daily";
    };

    oidc.providers.github = {
      issuer = "https://token.actions.githubusercontent.com";
      audience = "https://cache.r3dlust.com";

      rules = [
        {
          scopes = [ "write" ];
          pins = [ "zed-*" ];
          boundClaims = {
            repository = [ "GustavoWidman/zed-autobuild" ];
            event_name = [ "schedule" "workflow_dispatch" ];
            ref = [ "refs/heads/master" ];
            workflow_ref = [ "GustavoWidman/zed-autobuild/.github/workflows/build.yml@refs/heads/master" ];
          };
        }
        {
          scopes = [ "write" ];
          boundClaims = {
            repository_owner = [ "GustavoWidman" ];
            event_name = [ "push" ];
            ref = [ "refs/heads/*" ];
          };
        }
        {
          scopes = [ "write" ];
          boundClaims = {
            repository = [ "c0h1b4/oxi" ];
            event_name = [ "push" ];
            ref = [ "refs/heads/*" ];
          };
        }
      ];
    };
  };

  services.caddy= {
    enable = true;
    virtualHosts.${s3Url}.extraConfig = ''
      ${config.networking.certificates.${s3Url}.paths.caddy}

      # Preserve the signed Host, path, and query; never strip the bucket prefix.
      @cacheBucket path /${bucket} /${bucket}/*
      handle @cacheBucket {
        reverse_proxy ${config.services.niks3.s3.endpoint} {
          transport http {
            dial_timeout 5s
            response_header_timeout 300s
            keepalive 2m
          }
        }
      }

      handle {
        respond "Not found" 404
      }
    '';
    virtualHosts.${url} = {
      extraConfig = ''
        ${config.networking.certificates.${url}.paths.caddy}

        reverse_proxy ${config.services.niks3.httpAddr} {
          transport http {
            dial_timeout 5s
            response_header_timeout 60s
            keepalive 2m
          }
        }
      '';
    };
  };
}
