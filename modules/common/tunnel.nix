{ coeus, lib, ... }:
let
  id = "97355560-d822-4fcf-9fe7-e359a026ff85";
in
{
  # every server connects to this tunnel, so its name belongs to the fleet
  # rather than to any one machine
  cloudflare.fleet.dns."coeus.r3dlust.com".cname = {
    target = "${id}.cfargotunnel.com";
    proxied = true;
  };

  cloudflare.account = "471fb436adccbe82b805cad292e8671d";

  # answers with coeus's own offline page when no server is connected to the
  # tunnel; the dashboard's api and live stream bypass it
  cloudflare.fleet.workers.coeus-offline = {
    module = coeus.lib.offlineWorker { hosts = lib.coeusWebHosts; };
    compatibilityDate = "2026-11-01";
    routes = [ "coeus.r3dlust.com/*" ];
    bypass = [ "coeus.r3dlust.com/api/*" ];
  };
}
