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
    extraUpFlags = cfg.up-flags;
    extraSetFlags = cfg.up-flags;
    useRoutingFeatures = mkIf (cfg.exit-node || length cfg.advertise-routes > 0) "server";
  };
}
