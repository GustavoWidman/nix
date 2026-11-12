# the tailnet every machine can join: the options both platforms share, the
# flags they join with, and the fleet's auth key. modules/linux/tailscale.nix
# hands them to the nixos service, modules/macos/tailscale.nix to a launchd
# daemon that signs the mac in.
{
  config,
  isDarwin,
  lib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    length
    mkIf
    mkOption
    optional
    types
    ;

  cfg = config.tailscale;
in
{
  options.tailscale = {
    enable = mkOption {
      type = types.bool;
      # macs that run the Tailscale app sign in through it instead
      default = !isDarwin;
      defaultText = "true on nixos, false on darwin";
      description = "Whether to run tailscaled and join the tailnet with the fleet's auth key.";
    };

    advertise-routes = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of IP routes to advertise to the Tailscale network, e.g. [ \"10.0.0.0/8\" \"192.168.0.0/24\" ].";
    };

    exit-node = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this device should act as an exit node for the Tailscale network.";
    };

    up-flags = mkOption {
      type = types.listOf types.str;
      internal = true;
      readOnly = true;
      description = "The flags `tailscale up` joins the tailnet with, following the options above.";
    };
  };

  config = {
    tailscale.up-flags = [
      "--accept-dns=false"
    ]
    ++ optional cfg.exit-node "--advertise-exit-node=true"
    ++ optional (length cfg.advertise-routes > 0) (
      "--advertise-routes=" + concatStringsSep "," cfg.advertise-routes
    );

    services.tailscale.enable = mkIf cfg.enable true;

    secrets.tailscale-key = mkIf config.services.tailscale.enable {
      file = ./auth-key.age;
    };
  };
}
