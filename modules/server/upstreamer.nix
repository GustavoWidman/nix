# upstreamer, the reverse proxy and static file server of every server: a
# host turns it on with services.upstreamer.enable, and the files that run a
# site add its services.upstreamer.virtualHosts. a tls host gets an acme
# certificate named after it, ordered with security.acme.defaults from
# modules/server/acme, and is answered with a self-signed one until it is
# issued.
#
# every site writes an access log under /var/log/upstreamer, rotated daily,
# as caddy's did; a site can still turn its own off.
{ lib, upstreamer, ... }:
{
  imports = [ upstreamer.nixosModules.default ];

  options.services.upstreamer.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        config.accessLog.enable = lib.mkDefault true;
      }
    );
  };
}
