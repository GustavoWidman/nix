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
          whitelist.prefix = [ config.homeDir ];
        };
        silent = true;
        nix-direnv.enable = true;
      };
    }
  ];
}
