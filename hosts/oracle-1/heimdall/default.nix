{ config, heimdall, ... }:
let
  domain = "heimdall.r3dlust.com";
in
{
  imports = [ heimdall.nixosModules.default ];

  networking.certificates.${domain} = {
    enable = true;
    group = "dns-certs";
    users = [ "caddy" ];
  };

  # Holds the argon2id hash of the password, read as root by systemd and handed to the
  # service as a credential.
  secrets.heimdall-password.file = ./password.age;

  # Caddy serves the web app from its files and proxies /api to heimdall.
  services.heimdall = {
    enable = true;
    virtualHost = domain;
    passwordHashFile = config.secrets.heimdall-password.path;
  };

  services.caddy.virtualHosts.${domain}.extraConfig =
    config.networking.certificates.${domain}.paths.caddy;
}
