{
  config,
  dnsConfig,
  lib,
  ...
}:
let
  inherit (lib)
    enabled
    ;
in
{
  networking.search = config.dns.search;
  networking.nameservers = "127.0.0.1";

  services.dnsproxy = enabled {
    flags = [
      "--config-path"
      dnsConfig.dnsproxy
    ];
  };
}
