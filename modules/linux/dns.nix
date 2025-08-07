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
  services.coredns = lib.mkIf config.isLinux {
    enable = true;
    package = coredns;
    config = builtins.readFile ../common/dns/Corefile;
  };
}
