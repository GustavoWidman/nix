{ config, heimdall, ... }:
let
  domain = "heimdall.r3dlust.com";
in
{
  imports = [ heimdall.nixosModules.default ];

  cloudflare.dns.${domain}.a.proxied = true;

  # Holds the argon2id hash of the password, read as root by systemd and handed to the
  # service as a credential.
  secrets.heimdall-password.file = ./password.age;

  # upstreamer serves the web app from its files and proxies /api to heimdall, over TLS
  # with a certificate named after the host.
  services.heimdall = {
    enable = true;
    proxy = "upstreamer";
    virtualHost = domain;
    passwordHashFile = config.secrets.heimdall-password.path;
  };
}
