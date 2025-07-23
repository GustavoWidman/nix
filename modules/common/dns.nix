{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkDnsConfig
    ;
in
{
  options.dns = mkDnsConfig {
    servers = [
      "https://dns.r3dlust.com/dns-query"
    ];
    fallback-servers = [
      "https://dns.google/dns-query"
      "https://cloudflare-dns.com/dns-query"
    ];
    bootstrap-servers = [
      "129.148.24.25"
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

  config._module.args.dnsConfig = {
    dnsproxy = pkgs.writeText "dnsproxy.yml" (
      builtins.toJSON {
        listen-addrs = [ "127.0.0.1" ];

        upstream =
          config.dns.servers
          ++ lib.optional (config.dns.tailscale.enable) "[/ts.net/]${config.dns.tailscale.server}";
        fallback = config.dns.fallback-servers;
        bootstrap = config.dns.bootstrap-servers;
      }
    );

    searchDomainsString = lib.concatStringsSep " " (map (domain: "\"${domain}\"") config.dns.search);
  };
}
