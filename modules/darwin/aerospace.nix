{ lib, ... }:
let
  inherit (lib)
    enabled
    mkIf
    ;
in
{
  services.aerospace = {
    enable = false;
  };
}
