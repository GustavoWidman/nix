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
  };

  services.tailscale.derper = enabled {
    port = 48822;
    domain = "derp.r3dlust.com";
    openFirewall = false;
    verifyClients = true;
    configureNginx = false; # we use caddy in this house
  };

  services.caddy.virtualHosts."${domain}" = {
    extraConfig = ''
      ${config.networking.certificates."${domain}".paths.caddy}

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
