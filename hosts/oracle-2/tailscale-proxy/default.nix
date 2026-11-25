# tailscale.r3dlust.com fronts Tailscale's coordination servers for networks that block them:
# clients run `tailscale up --login-server https://tailscale.r3dlust.com`.
let
  origin = host: {
    to = "https://${host}";
    headers.Host = host;
  };
in
{
  cloudflare.dns."tailscale.r3dlust.com".a.proxied = true;

  services.upstreamer.virtualHosts."tailscale.r3dlust.com".routes = [
    {
      when.path = "/health";
      respond.body = "OK\n";
    }
    {
      # The key fetch, the /ts2021 upgrade to the Noise channel, and the client API.
      when.path = [
        "/ts2021"
        "/key"
        "/key/*"
        "/api/*"
        "/machine/*"
        "/register*"
        "/bootstrap-dns*"
        "/c/*"
      ];
      proxy = origin "controlplane.tailscale.com";
    }
    # Everything else is the web login.
    { proxy = origin "login.tailscale.com"; }
  ];
}
