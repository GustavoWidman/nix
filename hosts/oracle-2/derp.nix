{ config, lib, ... }:
let
  inherit (lib)
    enabled
    ;

  domain = "derp.r3dlust.com";
in
{
  networking.certificates."${domain}" = {
    enable = true;
    group = "caddy-certs";
    users = [
      "caddy"
    ];

    postRun = ''
      systemctl reload-or-restart caddy.service
    '';
  };

  services.tailscale.derper = enabled {
    port = 48822;
    domain = "derp.r3dlust.com";
    openFirewall = false;
    verifyClients = false; # TODO check if this works
    configureNginx = false; # we use caddy in this house
  };

  services.caddy.virtualHosts."${domain}" = {
    extraConfig = ''
      tls ${config.networking.certificates."${domain}".paths.fullchain} ${
        config.networking.certificates."${domain}".paths.key
      }

      reverse_proxy localhost:${toString config.services.tailscale.derper.port} {
        flush_interval -1

        transport http {
          read_timeout 3600s
          write_timeout 3600s
        }
      }
    '';
  };

  networking.firewall.allowPing = true;

  networking.firewall.allowedUDPPorts = [ config.services.tailscale.derper.stunPort ];
}
