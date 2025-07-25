{
  pkgs,
  config,
  lib,
  ...
}:
{
  environment.systemPackages = [ pkgs.dnsproxy ];

  launchd.daemons.dnsproxy = {
    command = "${pkgs.dnsproxy}/bin/dnsproxy --config-path ${config.dns.dnsproxy-config}";
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardErrorPath = "/var/log/dnsproxy.log";
      StandardOutPath = "/var/log/dnsproxy.log";
    };
  };

  networking.dns = [ "127.0.0.1" ];
  networking.search = config.dns.search;
  networking.knownNetworkServices = [
    "Wi-Fi"
    "Thunderbolt Bridge"
    "USB 10/100/1000 LAN" # Ethernet adapter
  ]
  ++ lib.optional (config.dns.tailscale.enable) "Tailscale";
}
