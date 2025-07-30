{ config, lib, ... }:
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

    postRun = ''
      systemctl reload-or-restart adguardhome.service
      systemctl reload-or-restart caddy.service
    '';
  };

  services.caddy = {
    enable = true;
    virtualHosts."dns.r3dlust.com" = {
      extraConfig = ''
        tls ${config.networking.certificates."dns.r3dlust.com".paths.fullchain} ${
          config.networking.certificates."dns.r3dlust.com".paths.key
        }

        reverse_proxy /* {
          to https://127.0.0.1:3443

          transport http {
            tls_insecure_skip_verify
          }

          header_up Host {host}
          header_up X-Real-IP {remote}
          header_up X-Forwarded-For {remote}
          header_up X-Forwarded-Proto {scheme}
        }
      '';
    };
  };

  secrets.adguardhome-config = {
    file = ./config.age;

    owner = "adguardhome";
    group = "adguardhome";
    mode = "0600";
  };
  services.adguardhome = enabled {
    host = "127.0.0.1";
    port = 3000;
    settings = null;
    mutableSettings = false;
  };

  systemd.services.adguardhome = {
    #! Reference:
    # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/networking/adguardhome.nix

    preStart = lib.mkForce ''
      cp --force "${config.secrets.adguardhome-config.path}" "$STATE_DIRECTORY/AdGuardHome.yaml"
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
    home = "/var/lib/private/AdGuardHome";
    isSystemUser = true;
    createHome = true;
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/private/AdGuardHome 0755 adguardhome adguardhome - -"
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
