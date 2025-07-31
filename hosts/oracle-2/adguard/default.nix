{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    enabled
    ;
in
{
  networking.certificates."dns.r3dlust.com" = {
    enable = true;
    group = "dns-certs";
    users = [
      "adguardhome"
      "caddy"
    ];

    postRun = # sh
      ''
        systemctl reload-or-restart adguardhome.service
        systemctl reload-or-restart caddy.service
      '';
  };

  services.caddy = {
    enable = true;
    virtualHosts."dns.r3dlust.com" = {
      extraConfig = # caddyfile
        ''
          tls ${config.networking.certificates."dns.r3dlust.com".paths.fullchain} ${
            config.networking.certificates."dns.r3dlust.com".paths.key
          }

          reverse_proxy /* {
            to https://127.0.0.1:3443

            transport http {
              tls_insecure_skip_verify
            }

            header_up Host {host}
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-For {remote_host}
            header_up X-Forwarded-Proto {scheme}

            header_up X-Original-IP {remote_host}
            header_up CF-Connecting-IP {remote_host}
          }
        '';
    };
  };

  services.adguardhome = enabled {
    host = "127.0.0.1";
    port = 3000;
    settings = {
      http = {
        address = "127.0.0.1:3000";
      };

      dns = {
        # i'd like to be able to specify what host i want to bind each port in
        # i don't like binding 3443 to 0.0.0.0, i'd like to have
        # 127.0.0.0.1:3443 -> 0.0.0.0:443 (via caddy)
        # 0.0.0.0:853 (DNS over TLS, exposed)
        # but... it's whatever, the firewall holds it, i guess.

        bind_hosts = [ "0.0.0.0" ];
        port = 0;

        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "tls://one.one.one.one"
          "https://dns.google/dns-query"
          "tls://dns.google"
        ];
        upstream_mode = "load_balance";
        bootstrap_dns = [
          "1.1.1.1"
          "1.0.0.1"
          "8.8.8.8"
          "8.8.4.4"
        ];

        serve_http3 = true;
        use_http3_upstreams = true;
        enable_dnssec = true;

        serve_plain_dns = true;
        hostsfile_enabled = false;
        use_private_ptr_resolvers = false;
      };

      tls = {
        enabled = true;
        server_name = "dns.r3dlust.com";
        certificate_path = config.networking.certificates."dns.r3dlust.com".paths.fullchain;
        private_key_path = config.networking.certificates."dns.r3dlust.com".paths.key;

        port_https = 3443;
        port_dns_over_tls = 853;
        port_dns_over_quic = 0; # disabled
        port_dnscrypt = 0; # disabled

        allow_unencrypted_doh = true;
        force_https = false;
      };
    };
    mutableSettings = false;
  };
  secrets.adguardhome-config = {
    file = ./config.yaml.age;
    owner = "adguardhome";
    group = "adguardhome";
    mode = "0600";
  };

  systemd.services.adguardhome =
    let
      baseConfig = (
        (pkgs.formats.yaml { }).generate "AdGuardHome.yaml" config.services.adguardhome.settings
      );
    in
    {
      #! Reference:
      # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/networking/adguardhome.nix

      preStart =
        lib.mkForce # sh
          ''
            ${lib.getExe pkgs.yaml-merge} "${config.secrets.adguardhome-config.path}" "${baseConfig}" > "$STATE_DIRECTORY/AdGuardHome.yaml"

            chmod 600 "$STATE_DIRECTORY/AdGuardHome.yaml"
          '';

      serviceConfig = {
        User = "adguardhome";
        Group = "adguardhome";
        DynamicUser = lib.mkForce false;
      };
    };

  users.users.adguardhome = {
    name = "adguardhome";
    group = "adguardhome";
    home = "/var/lib/AdGuardHome";
    isSystemUser = true;
    createHome = true;
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/AdGuardHome 0700 adguardhome adguardhome - -"
  ];
  users.groups.adguardhome = {
    name = "adguardhome";
  };

  networking.firewall = {
    allowedTCPPorts = [
      443
      853
    ];
  };
}
