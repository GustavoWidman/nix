# the tailnet every machine can join: the options both platforms share, the
# flags they join with, and the fleet's auth key. modules/linux/tailscale.nix
# hands them to the nixos service, modules/macos/tailscale.nix to a launchd
# daemon that signs the mac in.
#
# the key is an OAuth client's secret, which never expires. a machine it
# signs in is owned by the fleet's tag instead of a person, so it joins
# preauthorized and as a node that stays when it goes offline.
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

    tags = mkOption {
      type = types.listOf types.str;
      default = [ "tag:fleet" ];
      description = "The tags a machine joins the tailnet with; the auth key's OAuth client must own them.";
    };

    up-flags = mkOption {
      type = types.listOf types.str;
      internal = true;
      readOnly = true;
      description = "The settings `tailscale up` and `tailscale set` apply, following the options above.";
    };

    join-flags = mkOption {
      type = types.listOf types.str;
      internal = true;
      readOnly = true;
      description = "The flags `tailscale up` joins the tailnet with: the settings, and the tags, which only a join may change.";
    };

    auth-key-parameters = mkOption {
      type = types.str;
      internal = true;
      readOnly = true;
      description = "What an OAuth client's secret is suffixed with to sign a machine in.";
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

    tailscale.join-flags = cfg.up-flags ++ [ "--advertise-tags=${concatStringsSep "," cfg.tags}" ];
    tailscale.auth-key-parameters = "?ephemeral=false&preauthorized=true";

    services.tailscale.enable = mkIf cfg.enable true;

    secrets.tailscale-key = mkIf config.services.tailscale.enable {
      file = ./auth-key.age;
    };
  };
}
