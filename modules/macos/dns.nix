{
  pkgs,
  ...
}:
{
  launchd.daemons.dnsproxy = {
    command = "${pkgs.dnsproxy}/bin/dnsproxy --config-path=${../common/dns/config.yaml}";
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/var/log/dnsproxy.log";
      StandardErrorPath = "/var/log/dnsproxy.log";
    };
  };

  networking.dns = [ "127.0.0.1" ];
  networking.knownNetworkServices = [
    "Wi-Fi"
    "Thunderbolt Bridge"
    "USB 10/100/1000 LAN"
    "Tailscale"
  ];
}
