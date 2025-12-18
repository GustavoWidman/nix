{ config, lib, ... }:
let
  inherit (lib)
    enabled
    ;
in
{
  networking.certificates."courses.r3dlust.com" = {
    enable = true;
    group = "caddy-certs";
    users = [
      "caddy"
    ];

    postRun = ''
      systemctl reload-or-restart caddy.service
    '';
  };

  secrets.telegram-fwd-config.file = ./config.toml.age;

  services.telegram-fwd = enabled {
    config = config.secrets.telegram-fwd-config.path;
  };

  services.caddy.virtualHosts."courses.r3dlust.com" = {
    extraConfig = ''
      ${config.networking.certificates."courses.r3dlust.com".paths.caddy}

      reverse_proxy /* {
        to http://127.0.0.1:47787
      }
    '';
  };
}
