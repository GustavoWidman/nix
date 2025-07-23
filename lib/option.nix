_: _: super:
let
  inherit (super) mkOption types;
in
{
  mkConst =
    value:
    mkOption {
      default = value;
      readOnly = true;
    };

  mkValue = default: mkOption { inherit default; };

  mkDnsConfig = value: {
    servers = mkOption {
      type = types.listOf types.str;
      default =
        value.servers or [
          "1.1.1.1"
          "1.0.0.1"
          "8.8.8.8"
          "8.8.4.4"
        ];
      example = [
        "https://one.one.one.one/dns-query"
        "https://1.1.1.1/dns-query"
        "tls://1.1.1.1@one.one.one.one"
        "1.1.1.1"
      ];
      description = "Primary DNS servers to use.";
      readOnly = true;
    };
    fallback-servers = mkOption {
      type = types.listOf types.str;
      default = value.fallback-servers or [ ];
      example = [
        "https://dns.google/dns-query"
        "https://8.8.8.8/dns-query"
        "tls://8.8.8.8@dns.google"
        "8.8.8.8"
      ];
      description = "Fallback DNS servers to use if primary servers fail.";
      readOnly = true;
    };
    bootstrap-servers = mkOption {
      type = types.listOf types.str;
      default = value.bootstrap-servers or [ ];
      example = [
        "8.8.8.8"
        "1.1.1.1"
      ];
      description = "Bootstrap DNS servers to use for initial resolution of DoH or DoT servers.";
      readOnly = true;
    };

    tailscale = {
      enable = mkOption {
        type = types.bool;
        default = value.tailscale.enable or false;
        description = "Enable Tailscale DNS routing (route *.ts.net to tailscale's server)";
        readOnly = true;
      };

      server = mkOption {
        type = types.str;
        default = value.tailscale.server or "100.100.100.100";
        description = "Tailscale DNS server";
        readOnly = true;
      };

      readOnly = true;
    };

    search = mkOption {
      type = types.listOf types.str;
      default = value.search or [ ];
      example = [
        "example.net"
      ];
      description = "DNS search domains";
      readOnly = true;
    };
  };
}
