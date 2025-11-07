{ lib, ... }:
let
  inherit (lib)
    enabled
    ;
in
{
  home-manager.sharedModules = [
    {
      programs.uv = enabled {
        settings = {
          python-preference = "system";
        };
      };
    }
  ];
}
