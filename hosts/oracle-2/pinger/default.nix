{ config, lib, kemono-pinger, ... }:
let
  inherit (lib)
    enabled
    ;
in
{
  imports = [ kemono-pinger.nixosModules.default ];

  secrets.pinger-config.file = ./config.toml.age;

  services.kemono-pinger = enabled {
    config = config.secrets.pinger-config.path;
  };
}
