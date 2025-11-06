{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkForce
    enabled
    head
    ;

  domain = head config.mailserver.domains;

  mkUser = name: aliases: {
    "${name}@${domain}" = {
      aliases = (map (alias: "${alias}@${domain}") aliases);
      hashedPasswordFile = config.secrets."mail-${name}-passwd".path;
    };
  };
in
{
  networking.certificates."mail.r3dlust.com" = {
    enable = true;
    group = "mail-certs";
    users = [
      "caddy"
    ];

    postRun = ''
      systemctl reload-or-restart caddy.service
    '';
  };

  secrets = {
    mail-sasl-passwd.file = ./sasl_passwd.age;

    mail-admin-passwd.file = ./users/admin.age;
  };

  mailserver = enabled {
    stateVersion = 3;
    fqdn = "mail.r3dlust.com";
    domains = [ "r3dlust.com" ];

    localDnsResolver = false;

    loginAccounts = mkUser "admin" [ "postmaster" ];

    enableImap = true; # port 143
    enableImapSsl = true; # port 993
    enablePop3 = true; # port 110
    enablePop3Ssl = true; # port 995
    enableSubmission = true; # port 587
    enableSubmissionSsl = true; # port 465

    certificateScheme = "manual";
    certificateFile = config.networking.certificates."mail.r3dlust.com".paths.cert;
    keyFile = config.networking.certificates."mail.r3dlust.com".paths.key;

    openFirewall = true;
  };

  services.postfix = {
    mapFiles."sasl_passwd" = config.secrets.mail-sasl-passwd.path;

    settings.main = {
      smtp_sasl_auth_enable = true;
      smtp_sasl_password_maps = "hash:/etc/postfix/sasl_passwd";
      smtp_sasl_security_options = "noanonymous";
      smtp_sasl_tls_security_options = "noanonymous";
      smtp_sasl_mechanism_filter = "AUTH LOGIN";
      smtp_tls_security_level = mkForce "encrypt";
      relayhost = [ "[smtp-relay.brevo.com]:587" ];

      header_size_limit = mkForce 1048576;
      message_size_limit = mkForce 19922944;
    };
  };

  virtualisation.arion.projects.roundcube.settings = {
    services = {
      app.service = {
        image = "roundcube/roundcubemail";
        environment = {
          ROUNDCUBEMAIL_DB_TYPE = "sqlite";
          ROUNDCUBEMAIL_SKIN = "elastic";
          ROUNDCUBEMAIL_DEFAULT_HOST = "tls://mail.r3dlust.com";
          ROUNDCUBEMAIL_SMTP_SERVER = "tls://mail.r3dlust.com";
        };
        restart = "unless-stopped";
        volumes = [
          "roundcube-static:/app/backups"
          "roundcube-db:/var/roundcube/db"
        ];
        ports = [ "127.0.0.1:37993:80" ];
      };
    };

    docker-compose.volumes = {
      roundcube-static = { };
      roundcube-db = { };
    };
  };

  services.caddy.virtualHosts."mail.r3dlust.com" = {
    extraConfig = ''
      tls ${config.networking.certificates."mail.r3dlust.com".paths.fullchain} ${
        config.networking.certificates."mail.r3dlust.com".paths.key
      }

      reverse_proxy /* {
        to http://127.0.0.1:37993
      }
    '';
  };
}
