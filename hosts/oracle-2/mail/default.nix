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
    ;
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

    mail-dovecot.file = ./dovecot.age;
    mail-postfix.file = ./postfix.age;
  };

  mailserver = enabled {
    stateVersion = 3;
    fqdn = "mail.r3dlust.com";
    domains = [ "r3dlust.com" ];

    localDnsResolver = false;

    loginAccounts = { };

    enableImap = true; # port 143
    enableImapSsl = true; # port 993
    enablePop3 = true; # port 110
    enablePop3Ssl = true; # port 995
    enableSubmission = true; # port 587
    enableSubmissionSsl = true; # port 465

    x509 = {
      certificateFile = config.networking.certificates."mail.r3dlust.com".paths.cert;
      privateKeyFile = config.networking.certificates."mail.r3dlust.com".paths.key;
    };

    openFirewall = true;

    rejectRecipients = [ ];
    rejectSender = [ ];
  };

  systemd.services.dovecot = {
    preStart = mkForce ''
      mkdir -p /run/dovecot2
      chmod 755 /run/dovecot2
      cp ${config.secrets.mail-dovecot.path} /run/dovecot2/passwd
      ${pkgs.gawk}/bin/awk -F: '{print $1 ":::::::;"}' /run/dovecot2/passwd > /run/dovecot2/userdb
      chmod 600 /run/dovecot2/passwd /run/dovecot2/userdb
    '';

    restartTriggers = [
      config.secrets.mail-dovecot.path
    ];
  };

  services.postfix = {
    mapFiles.sasl_passwd = mkForce config.secrets.mail-sasl-passwd.path;
    mapFiles.valias = mkForce config.secrets.mail-postfix.path;
    mapFiles.vaccounts = mkForce config.secrets.mail-postfix.path;
    mapFiles.virtual = mkForce config.secrets.mail-postfix.path;

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
