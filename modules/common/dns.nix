{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkDnsConfig
    ;
in
{
  options.dns = mkDnsConfig pkgs {
    servers = [
      "https://dns.r3dlust.com/dns-query"
    ];
    fallback-servers = [
      "https://dns.google/dns-query"
      "https://cloudflare-dns.com/dns-query"
    ];
    bootstrap-servers = [
      "1.1.1.1"
      "1.0.0.1"
      "8.8.8.8"
      "8.8.4.4"
    ];

    tailscale = {
      enable = true;
      server = "100.100.100.100";
    };
    search = [
      "tail4a3ea.ts.net"
      "tailfae4d.ts.net"
    ];
  };
}
