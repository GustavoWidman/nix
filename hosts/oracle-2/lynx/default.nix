{
  arion,
  config,
  pkgs,
  ...
}:

{
  imports = [
    arion.nixosModules.arion
  ];

  networking.certificates."links.r3dlust.com" = {
    enable = true;
    group = "caddy-certs";
    users = [
      "caddy"
    ];

    postRun = ''
      systemctl reload-or-restart caddy.service
    '';
  };

  environment.systemPackages = with pkgs; [
    arion
    docker-client
  ];

  virtualisation.arion.backend = "docker";

  secrets.lynx-db-env.file = ./db.env.age;
  secrets.lynx-app-env.file = ./app.env.age;

  virtualisation.arion.projects.lynx.settings = {
    services = {
      lynx-db.service = {
        image = "mongo:7";
        env_file = [
          config.secrets.lynx-db-env.path
        ];
        volumes = [
          "/var/lib/lynx/data:/data/db"
        ];
        networks = [ "lynx" ];
        restart = "always";
      };

      lynx.service = {
        image = "jackbailey/lynx:1";
        env_file = [
          config.secrets.lynx-app-env.path
        ];
        volumes = [
          "/var/lib/lynx/backups:/app/backups"
        ];
        depends_on = [ "lynx-db" ];
        networks = [ "lynx" ];
        ports = [ "26638:3000" ];
      };
    };

    networks.lynx = { };
  };

  services.caddy.virtualHosts."links.r3dlust.com" = {
    extraConfig = ''
      tls ${config.networking.certificates."links.r3dlust.com".paths.fullchain} ${
        config.networking.certificates."links.r3dlust.com".paths.key
      }

      reverse_proxy /* {
        to http://127.0.0.1:26638
      }
    '';
  };
}
