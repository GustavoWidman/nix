{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    enabled
    optionalAttrs
    ;
in
{
  secrets.tailscale-key.file = ./auth-key.age;
  services.tailscale = enabled {
    enable = true;
    package = pkgs.tailscale;
    authKeyFile = config.secrets.tailscale-key.path;
  };
}
