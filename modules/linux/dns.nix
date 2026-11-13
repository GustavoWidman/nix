{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    enabled
    mkForce
    ;
in
{
  services.dnsproxy = enabled {
    flags = [ "--config-path=${../common/dns/config.yaml}" ];
  };

  networking.nameservers = [ "127.0.0.1" ];

  environment.etc."resolv.conf".text = mkForce ''
    search ${concatStringsSep " " config.networking.search}
    ${concatMapStringsSep "\n" (ns: "nameserver ${ns}") config.networking.nameservers}
  '';
}
