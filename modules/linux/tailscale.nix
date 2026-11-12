{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    length
    mkIf
    ;

  cfg = config.tailscale;
in
{
  services.tailscale = mkIf cfg.enable {
    package = pkgs.tailscale;
    authKeyFile = config.secrets.tailscale-key.path;
    # the same as the shared cfg.auth-key-parameters, in the nixos module's form
    authKeyParameters = {
      ephemeral = false;
      preauthorized = true;
    };
    extraUpFlags = cfg.join-flags;
    extraSetFlags = cfg.up-flags;
    useRoutingFeatures = mkIf (cfg.exit-node || length cfg.advertise-routes > 0) "server";
  };
}
