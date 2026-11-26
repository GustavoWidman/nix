# the tailnet's own DERP region, r3dlust: a derper on each machine in `nodes`,
# meshed so that a client on one node still reaches a client that is on the
# other. it is one region of several nodes rather than a region per machine
# because the machines share an Oracle availability domain: regions that close
# tie on latency, and clients keep moving their home between them, while inside
# one region a client dials the nodes in the policy's order and only moves on
# when one fails.
#
# the region is the only one the tailnet uses, so that a machine on a network
# that blocks Tailscale's own relays can still reach every peer's home. the
# tailnet policy carries it, with the nodes in this order:
#
#   "derpMap": {
#     "OmitDefaultRegions": true,
#     "Regions": {
#       "900": {
#         "RegionID": 900,
#         "RegionCode": "r3dlust",
#         "RegionName": "r3dlust",
#         "Nodes": [
#           { "Name": "900a", "RegionID": 900, "HostName": "derp-2.r3dlust.com" },
#           { "Name": "900b", "RegionID": 900, "HostName": "derp-1.r3dlust.com" }
#         ]
#       }
#     }
#   }
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    attrValues
    concatStringsSep
    getExe'
    mkForce
    mkIf
    ;

  nodes = {
    oracle-1 = "derp-1.r3dlust.com";
    oracle-2 = "derp-2.r3dlust.com";
  };

  domain = nodes.${config.networking.hostName} or null;
  cfg = config.services.tailscale.derper;
in
{
  config = mkIf (domain != null) {
    cloudflare.dns.${domain}.a = { };

    # 64 lowercase hex characters, the same on every node
    secrets.derp-mesh-key.file = ./mesh-key.age;

    services.tailscale.derper = {
      enable = true;
      port = 48822;
      inherit domain;
      # the stun port; upstreamer serves tcp 443
      openFirewall = true;
      verifyClients = true;
      configureNginx = false;
    };

    # the nixos module has no mesh options. derper runs as a dynamic user, so
    # the key reaches it as a credential
    systemd.services.tailscale-derper.serviceConfig = {
      LoadCredential = [ "mesh-key:${config.secrets.derp-mesh-key.path}" ];
      ExecStart = mkForce (
        concatStringsSep " " [
          (getExe' cfg.package "derper")
          "-a :${toString cfg.port}"
          "-c /var/lib/derper/derper.key"
          "-hostname=${domain}"
          "-stun-port ${toString cfg.stunPort}"
          "-verify-clients"
          "-mesh-psk-file=%d/mesh-key"
          "-mesh-with=${concatStringsSep "," (attrValues nodes)}"
        ]
      );
    };

    # the proxy writes each response chunk as it arrives. a DERP connection
    # that carries nothing either way for an hour is closed
    services.upstreamer.virtualHosts.${domain}.proxy = {
      to = "http://127.0.0.1:${toString cfg.port}";
      timeouts.tunnelIdle = "3600s";
    };
  };
}
