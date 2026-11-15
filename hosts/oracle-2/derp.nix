{ config, lib, ... }:
let
  inherit (lib)
    enabled
    ;

  domain = "derp.r3dlust.com";
in
{
  cloudflare.dns.${domain}.a = { };

  services.tailscale.derper = enabled {
    port = 48822;
    domain = "derp.r3dlust.com";
    openFirewall = false;
    verifyClients = true;
    configureNginx = false; # we use upstreamer in this house
  };

  # The proxy writes each response chunk as it arrives. A DERP connection that
  # carries nothing either way for an hour is closed.
  services.upstreamer.virtualHosts.${domain}.proxy = {
    to = "http://127.0.0.1:${toString config.services.tailscale.derper.port}";
    timeouts.tunnelIdle = "3600s";
  };

  networking.firewall.allowPing = true;

  networking.firewall.allowedUDPPorts = [ config.services.tailscale.derper.stunPort ];
}
