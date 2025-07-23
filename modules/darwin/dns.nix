{
  pkgs,
  config,
  lib,
  dnsConfig,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    ;

  searchDomains = concatStringsSep " " (map (domain: "\"${domain}\"") config.dns.search);

  dnsproxyScript = pkgs.writeShellScript "dnsproxy" ''
    truncate -s 0 /var/log/dnsproxy.log

    networksetup -listallnetworkservices \
      | grep -v "An asterisk" \
      | while read service; do
        networksetup -setdnsservers "$service" "127.0.0.1" 2>/dev/null;
      done

    networksetup -listallnetworkservices \
      | grep -v "An asterisk" \
      | while read service; do
        networksetup -setsearchdomains "$service" ${searchDomains} 2>/dev/null;
      done

    exec ${pkgs.dnsproxy}/bin/dnsproxy --config-path ${dnsConfig.dnsproxy}
  '';

in
{
  environment.systemPackages = [ pkgs.dnsproxy ];

  launchd.daemons.dnsproxy = {
    command = "${dnsproxyScript}";
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardErrorPath = "/var/log/dnsproxy.log";
      StandardOutPath = "/var/log/dnsproxy.log";
    };
  };

  networking.knownNetworkServices = [ ];
}
