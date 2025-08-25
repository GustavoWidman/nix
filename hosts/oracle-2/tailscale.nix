{
  pkgs,
  config,
  ...
}:
let
  proxyt = pkgs.buildGoModule {
    name = "proxyt";
    src = pkgs.fetchFromGitHub {
      owner = "jaxxstorm";
      repo = "proxyt";
      rev = "v0.0.5";
      sha256 = "sha256-kPyvUxEWcQuGE14J6vc6IuXKr71WNROB+ESopqHzQOs=";
    };

    vendorHash = "sha256-nVrmATVxBZvg1p/AMeAZbGmIn4EtBoxbwQolHCBDo4o=";
  };
in
{
  systemd.services.proxyt = {
    description = "proxyt service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${proxyt}/bin/proxyt serve -d tailscale.r3dlust.com --http-only --port 59553 --bind 127.0.0.1";
      Restart = "on-failure";
      User = "root";
      Group = "root";
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
    };
  };

  networking.certificates."tailscale.r3dlust.com" = {
    enable = true;
    group = "tailscale-certs";
    users = [
      "caddy"
    ];

    postRun = ''
      systemctl reload-or-restart caddy.service
    '';
  };

  services.caddy.virtualHosts."tailscale.r3dlust.com" = {
    extraConfig = ''
      tls ${config.networking.certificates."tailscale.r3dlust.com".paths.fullchain} ${
        config.networking.certificates."tailscale.r3dlust.com".paths.key
      }

      reverse_proxy /* {
        to http://127.0.0.1:59553

        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}

        header_up X-Original-IP {remote_host}
        header_up CF-Connecting-IP {remote_host}
      }
    '';
  };
}
