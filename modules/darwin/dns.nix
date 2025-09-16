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
}
