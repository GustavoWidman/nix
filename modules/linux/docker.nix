{ lib, ... }:
let
  inherit (lib)
    enabled
    ;
in
{
  virtualisation.docker = enabled {
    autoPrune.enable = true;
  };
}
