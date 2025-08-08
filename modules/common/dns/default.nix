{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    optionalAttrs
    mkForce
    concatStringsSep
    concatMapStringsSep
    ;

  searchDomains = [
    "tail4a3ea.ts.net"
    "tailfae4d.ts.net"
  ];
in
{
  networking =
    optionalAttrs config.isDarwin {
      dns = [ "127.0.0.1" ];
      search = searchDomains;
      knownNetworkServices = [
        "Wi-Fi"
        "Thunderbolt Bridge"
        "USB 10/100/1000 LAN"
        "Tailscale"
      ];
    }
    // optionalAttrs config.isLinux {
      search = searchDomains;
      nameservers = [ "127.0.0.1" ];
    };

  environment = optionalAttrs config.isLinux {
    etc."resolv.conf".text = mkForce ''
      search ${concatStringsSep " " config.networking.search}
      ${concatMapStringsSep "\n" (ns: "nameserver ${ns}") config.networking.nameservers}
    '';
  };
}
