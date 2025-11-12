{ config, lib, ... }:
let
  inherit (lib)
    enabled
    ;
in
{
  secrets.pinger-config.file = ./config.toml.age;

  services.kemono-pinger = enabled {
    config = config.secrets.pinger-config.path;
  };
}
