{
  lib,
  ...
}:
let
  inherit (lib)
    enabled
    ;
in
{
  services.dnsproxy = enabled {
    flags = [ "--config-path=${../common/dns/config.yaml}" ];
  };
}
