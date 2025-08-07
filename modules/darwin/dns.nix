{
  pkgs,
  lib,
  config,
  ...
}:
let
  coredns = pkgs.coredns.override {
    externalPlugins = [
      {
        name = "https";
        repo = "github.com/v-byte-cpu/coredns-https";
        version = "v0.1.0";
      }
    ];
    vendorHash = "sha256-wVOl1GyVZ8wU6QRz4Y3YN12EeudAiDwKmtY/LcquSWc=";
  };
in
{
  launchd.daemons.coredns = lib.mkIf config.isDarwin {
    command = "${coredns}/bin/coredns -conf ${../common/dns/Corefile}";
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/var/log/ctrld.log";
      StandardErrorPath = "/var/log/ctrld.log";
    };
  };
}
