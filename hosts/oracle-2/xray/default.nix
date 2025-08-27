{ config, lib, ... }:
let
  inherit (lib)
    enabled
    ;
in
{
  networking.certificates."r3dlust.com" = {
    enable = true;
    group = "main-certs";
    wildcard = true;
    users = [
      "caddy"
    ];

    postRun = ''
      systemctl reload-or-restart xray.service
      systemctl reload-or-restart caddy.service
    '';
  };

  secrets.xray-config = {
    file = ./config.json.age;
    owner = "xray";
    group = "xray";
  };

  services.xray = enabled {
    settingsFile = config.secrets."xray-config".path;
  };

  users.users.xray = {
    name = "xray";
    group = "xray";
    isSystemUser = true;
  };
  users.groups.xray = {
    name = "xray";
  };
  systemd.services.xray = {
    serviceConfig = {
      User = "xray";
      Group = "xray";
      DynamicUser = lib.mkForce false;
    };
  };

  services.caddy.virtualHosts."r3dlust.com" = {
    extraConfig = ''
      tls ${config.networking.certificates."r3dlust.com".paths.fullchain} ${
        config.networking.certificates."r3dlust.com".paths.key
      }

      handle /xray {
        reverse_proxy http://127.0.0.1:2001 {
          header_up Upgrade {http.request.header.Upgrade}
          header_up Connection {http.request.header.Connection}
          header_up Sec-WebSocket-Key {http.request.header.Sec-WebSocket-Key}
          header_up Sec-WebSocket-Version {http.request.header.Sec-WebSocket-Version}
          header_up Sec-WebSocket-Protocol {http.request.header.Sec-WebSocket-Protocol}
          header_up Sec-WebSocket-Extensions {http.request.header.Sec-WebSocket-Extensions}

          transport http {
            versions 1.1
          }
        }
      }

      handle {
        respond "there's nothing to see here, go away..." 404
      }
    '';
  };

  networking.firewall.allowedUDPPorts = [ 443 ];
}
