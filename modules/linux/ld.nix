{ lib, config, ... }:
let
  inherit (lib)
    mkIf
    ;
in
{
  programs.nix-ld.enable = mkIf config.isDevServer true;
}
