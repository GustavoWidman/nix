{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    length
    mkIf
    mkOption
    optional
    types
    ;

  cfg = config.tailscale;
  relay = cfg.relay;
in
{
  # a peer relay carries traffic between machines whose NATs never let them
  # connect directly, such as laptop-mac away from home and the machines on
  # lab's network, over UDP through a machine both sides reach. DERP still sets
  # each connection up and stays the fallback.
  options.tailscale.relay = {
    port = mkOption {
      type = types.nullOr types.port;
      default = null;
      description = "The UDP port this machine serves a peer relay on, or null to serve none. The tailnet policy must grant tailscale.com/cap/relay with this machine as dst.";
    };

    address = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The public IPv4 address the relay is advertised at, for a machine whose public address is not on any of its interfaces, such as behind a cloud's 1:1 NAT.";
    };
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      authKeyFile = config.secrets.tailscale-key.path;
      # the same as the shared cfg.auth-key-parameters, in the nixos module's form
      authKeyParameters = {
        ephemeral = false;
        preauthorized = true;
      };
      extraUpFlags = cfg.join-flags;
      # tailscale keeps relay settings in its own state, so a machine that
      # stops being a relay says so instead of leaving them unmanaged
      relayServerPort = if relay.port == null then "" else relay.port;
      extraSetFlags = cfg.up-flags ++ [
        "--relay-server-static-endpoints=${
          if relay.port != null && relay.address != null then
            "${relay.address}:${toString relay.port}"
          else
            ""
        }"
      ];
      useRoutingFeatures =
        let
          serves = cfg.exit-node || length cfg.advertise-routes > 0;
        in
        if serves && cfg.accept-routes then
          "both"
        else if serves then
          "server"
        else if cfg.accept-routes then
          "client"
        else
          "none";
    };

    networking.firewall.allowedUDPPorts = optional (relay.port != null) relay.port;
  };
}
