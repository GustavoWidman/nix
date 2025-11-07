{
  lib,
  config,
  ...
}:

let
  inherit (lib)
    enabled
    ;
in
{
  networking.certificates."gemini.r3dlust.com" = {
    enable = true;
    group = "caddy-certs";
    users = [
      "caddy"
    ];

    postRun = ''
      systemctl reload-or-restart caddy.service
    '';
  };

  secrets.gemini-juggler-config = {
    file = ./config.toml.age;
    owner = config.services.gemini-juggler.user;
  };

  services.gemini-juggler = enabled {
    config = config.secrets.gemini-juggler-config.path;
  };

  services.caddy.virtualHosts."gemini.r3dlust.com" = {
    extraConfig = ''
      tls ${config.networking.certificates."gemini.r3dlust.com".paths.fullchain} ${
        config.networking.certificates."gemini.r3dlust.com".paths.key
      }

      reverse_proxy /* {
        to http://127.0.0.1:57061
      }
    '';
  };
}
