# upstreamer, the reverse proxy and static file server of every server: a
# host turns it on with services.upstreamer.enable, and the files that run a
# site add its services.upstreamer.virtualHosts. a tls host gets an acme
# certificate named after it, ordered with security.acme.defaults from
# modules/server/acme, and is answered with a self-signed one until it is
# issued.
{ upstreamer, ... }:
{
  imports = [ upstreamer.nixosModules.default ];
}
