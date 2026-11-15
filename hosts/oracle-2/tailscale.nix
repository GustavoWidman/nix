{ pkgs, ... }:
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

  cloudflare.dns."tailscale.r3dlust.com".a.proxied = true;

  # Host, X-Forwarded-For and X-Forwarded-Proto are the proxy's defaults.
  services.upstreamer.virtualHosts."tailscale.r3dlust.com".proxy = {
    to = "http://127.0.0.1:59553";
    headers = {
      X-Real-IP = "{remote_host}";
      X-Original-IP = "{remote_host}";
      CF-Connecting-IP = "{remote_host}";
    };
  };
}
