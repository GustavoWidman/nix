{
  coeus,
  config,
  lib,
  ...
}:
let
  id = "97355560-d822-4fcf-9fe7-e359a026ff85";
  name = "coeus.r3dlust.com";
  web = config.services.coeus.web;
in
{
  # every server connects to this tunnel, so its name belongs to the fleet
  # rather than to any one machine
  cloudflare.fleet.dns.${name}.cname = {
    target = "${id}.cfargotunnel.com";
    proxied = true;
  };

  cloudflare.account = "471fb436adccbe82b805cad292e8671d";

  # answers with coeus's own offline page when no server is connected to the
  # tunnel; the dashboard's api and live stream bypass it
  cloudflare.fleet.workers.coeus-offline = {
    module = coeus.lib.offlineWorker { hosts = lib.coeusWebHosts; };
    compatibilityDate = "2026-11-01";
    routes = [ "${name}/*" ];
    bypass = [ "${name}/api/*" ];
  };

  # the dashboard itself, served from every serving machine through the
  # tunnel. its secrets live under modules/server so only those machines (and
  # the admins) open them. on a mac, coeus web runs as its own user, which has
  # to own them; on nixos systemd hands them over as credentials.
  secrets = lib.mkIf web.enable {
    coeus-session-key = {
      file = ../server/tunnel/session-key.age;
      owner = lib.mkIf config.isDarwin "_coeusweb";
    };
    coeus-tunnel = {
      file = ../server/tunnel/credentials.age;
      owner = lib.mkIf config.isDarwin "_coeusweb";
    };
  };

  services.coeus.web = lib.mkIf (lib.servesCoeusWeb config.metadata) {
    enable = true;
    publicOrigin = "https://${name}";
    sessionKeyFile = config.secrets.coeus-session-key.path;
    # signing in happens on the tailnet alone, on any serving machine
    signin.urls = map (
      host: "https://${host}.tail4a3ea.ts.net:${toString web.signin.port}"
    ) lib.coeusWebHosts;
    tunnel = {
      inherit id;
      credentialsFile = config.secrets.coeus-tunnel.path;
    };
  };
}
