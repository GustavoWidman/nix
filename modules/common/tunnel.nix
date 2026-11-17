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
}
