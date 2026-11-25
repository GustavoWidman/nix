# phoebe's app, on every node: served at phoebe.r3dlust.com through a
# cloudflare tunnel every node connects to, and signed in to on the tailnet.
# its secrets live under modules/server/phoebe, which the nodes and the admins
# open. on nixos systemd hands the app the session key and the tunnel's
# credentials as credentials, so those stay root's, and the app reads the push
# key and the list as phoebe-web; on a mac it reads every file as _phoebe.
{
  config,
  lib,
  phoebe,
  ...
}:
let
  name = "phoebe.r3dlust.com";
  web = config.services.phoebe.web;
  user = if config.isDarwin then "_phoebe" else "phoebe-web";
  # the tunnel every node connects to; `cloudflared tunnel create` wrote its
  # credentials, in ../../server/phoebe/tunnel-credentials.age
  id = "dfc628d2-547c-4ad3-ad6a-09e201ee46fb";
in
{
  # every node connects to the tunnel, so its name belongs to the fleet
  # rather than to any one machine
  cloudflare.fleet.dns.${name}.cname = {
    target = "${id}.cfargotunnel.com";
    proxied = true;
  };

  # answers with phoebe's own offline page when no node is connected to the
  # tunnel; the app's api and live streams bypass it
  cloudflare.fleet.workers.phoebe-offline = {
    module = phoebe.lib.offlineWorker { inherit (lib.phoebeFleet) nodes; };
    compatibilityDate = "2026-11-01";
    routes = [ "${name}/*" ];
    bypass = [ "${name}/api/*" ];
  };

  secrets = lib.mkIf web.enable {
    phoebe-session-key = {
      file = ../../server/phoebe/session-key.age;
      owner = lib.mkIf config.isDarwin user;
    };
    phoebe-vapid = {
      file = ../../server/phoebe/vapid.age;
      owner = user;
    };
    phoebe-push-subscriptions = {
      file = ../../server/phoebe/subscriptions.age;
      owner = user;
    };
    phoebe-tunnel = {
      file = ../../server/phoebe/tunnel-credentials.age;
      owner = lib.mkIf config.isDarwin user;
    };
  };

  services.phoebe.web = lib.mkIf (lib.elem config.networking.hostName lib.phoebeFleet.nodes) {
    enable = true;
    publicOrigin = "https://${name}";
    sessionKeyFile = config.secrets.phoebe-session-key.path;
    # every node signs in at https://<node>.tail4a3ea.ts.net:45731
    signin.domain = "tail4a3ea.ts.net";
    tunnel = {
      inherit id;
      credentialsFile = config.secrets.phoebe-tunnel.path;
    };
    # a page alert goes to every device on the list; a device subscribes on
    # the app's device screen, which shows the entry to add
    push = {
      vapidKeyFile = config.secrets.phoebe-vapid.path;
      subscriptionsFile = config.secrets.phoebe-push-subscriptions.path;
      edit = "agenix -e modules/server/phoebe/subscriptions.age";
    };
  };
}
