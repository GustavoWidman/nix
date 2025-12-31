{ config, ... }:

{
  networking.certificates."minecraft.r3dlust.com" = {
    enable = true;
    group = "caddy-certs";
    users = [
      "caddy"
    ];

    postRun = ''
      systemctl reload-or-restart caddy.service
    '';
  };

  virtualisation.arion.projects.mcsmanager.settings = {
    services = {
      web.service = {
        image = "githubyumao/mcsmanager-web:latest";
        restart = "unless-stopped";
        ports = [ "127.0.0.1:27613:23333" ];
        volumes = [
          "/var/lib/mcsmanager/web/data:/opt/mcsmanager/web/data"
          "/var/lib/mcsmanager/web/logs:/opt/mcsmanager/web/logs"
          "/etc/localtime:/etc/localtime:ro"
        ];
      };

      daemon.service = {
        image = "githubyumao/mcsmanager-daemon:latest";
        restart = "unless-stopped";
        ports = [
          "127.0.0.1:52930:24444"
          "25565:25565"
          "25566:25566"
        ];
        environment = {
          MCSM_DOCKER_WORKSPACE_PATH = "/var/lib/mcsmanager/daemon/data/InstanceData";
        };
        volumes = [
          "/var/lib/mcsmanager/daemon/data:/opt/mcsmanager/daemon/data"
          "/var/lib/mcsmanager/daemon/logs:/opt/mcsmanager/daemon/logs"
          "/etc/localtime:/etc/localtime:ro"
          "/var/run/docker.sock:/var/run/docker.sock"
        ];
      };
    };
  };

  networking.firewall = {
    allowedUDPPorts = [
      25565
      25566
      25567
    ];
    allowedTCPPorts = [
      25565
      25566
      25567
    ];
  };

  services.caddy.virtualHosts."minecraft.r3dlust.com" = {
    extraConfig = ''
      ${config.networking.certificates."minecraft.r3dlust.com".paths.caddy}

      handle_path /daemon/* {
        reverse_proxy http://127.0.0.1:52930
      }

      handle {
        reverse_proxy /* {
          to http://127.0.0.1:27613
        }
      }
    '';
  };
}
