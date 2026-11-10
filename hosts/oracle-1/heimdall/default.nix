{ config, ... }:
let
  domain = "heimdall.r3dlust.com";
in
{
  networking.certificates.${domain} = {
    enable = true;
    group = "dns-certs";
    users = [ "caddy" ];

    postRun = ''
      systemctl reload-or-restart caddy.service
    '';
  };

  # Read as root by systemd and handed to the service as a credential.
  secrets.heimdall-password-hash.file = ./password-hash.age;

  services.heimdall = {
    enable = true;
    passwordHashFile = config.secrets.heimdall-password-hash.path;
  };

  # A plain proxy is enough: Caddy keeps Host and sets X-Forwarded-Proto for
  # heimdall's same-origin check, and flushes the event stream of /api/live.
  services.caddy.virtualHosts.${domain}.extraConfig = ''
    ${config.networking.certificates.${domain}.paths.caddy}

    reverse_proxy ${config.services.heimdall.listen}
  '';
}
