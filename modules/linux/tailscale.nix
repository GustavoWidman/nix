{
  config,
  lib,
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
    authKeyFile = config.secrets.tailscale-key.path;
    # the same as the shared cfg.auth-key-parameters, in the nixos module's form
    authKeyParameters = {
      ephemeral = false;
      preauthorized = true;
    };
    extraUpFlags = cfg.join-flags;
    extraSetFlags = cfg.up-flags;
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
}
