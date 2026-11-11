{ config, lib, ... }:
let
  inherit (lib)
    enabled
    ;
in
{
  home-manager.sharedModules = [
    {
      programs.direnv = enabled {
        config = {
          # whitelist.prefix = [ config.homeDir ];
          global.warn_timeout = "15m";
        };
        silent = true;
        # The nushell config runs direnv itself, only where an .envrc applies.
        enableNushellIntegration = false;
        nix-direnv.enable = true;
      };
    }
  ];
}
