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
          global.log_filter = "^loading";
          whitelist.prefix = [ config.homeDir ];
        };
      };
    }
  ];
}
