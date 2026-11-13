{
  config,
  lib,
  pkgs,
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

  # started once it answers, so a unit ordered after it can resolve names as it starts
  systemd.services.dnsproxy.serviceConfig.ExecStartPost = pkgs.writeShellScript "dnsproxy-listening" ''
    until (exec 3<>/dev/tcp/127.0.0.1/53) 2>/dev/null; do sleep 0.1; done
  '';

  networking.nameservers = [ "127.0.0.1" ];

  environment.etc."resolv.conf".text = mkForce ''
    search ${concatStringsSep " " config.networking.search}
    ${concatMapStringsSep "\n" (ns: "nameserver ${ns}") config.networking.nameservers}
  '';
}
