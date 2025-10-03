{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    length
    mkIf
    ;
in
{
  config = {
    secrets.tailscale-key.file = ./auth-key.age;
    services.tailscale = mkIf config.tailscale.enable {
      enable = true;
      package = pkgs.tailscale;
      authKeyFile = config.secrets.tailscale-key.path;
      extraUpFlags = [
        "--accept-dns=false"
      ]
      ++ (lib.optional config.tailscale.exit-node "--advertise-exit-node=true")
      ++ (lib.optional (length config.tailscale.advertise-routes > 0) (
        "--advertise-routes=" + (lib.concatStringsSep "," config.tailscale.advertise-routes)
      ));
      extraSetFlags = config.services.tailscale.extraUpFlags;
      useRoutingFeatures = mkIf (
        config.tailscale.exit-node || (length config.tailscale.advertise-routes > 0)
      ) "server";
    };
  };

  options.tailscale = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Tailscale on this device.";
    };

    advertise-routes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of IP routes to advertise to the Tailscale network, e.g. [ \"10.0.0.0/8\" \"192.168.0.0/24\" ].";
    };

    exit-node = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether this device should act as an exit node for the Tailscale network.";
    };
  };
}
