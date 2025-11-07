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

    certificateScheme = "manual";
    certificateFile = config.networking.certificates."mail.r3dlust.com".paths.cert;
    keyFile = config.networking.certificates."mail.r3dlust.com".paths.key;

    openFirewall = true;
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
    mapFiles = mkForce {
      sasl_passwd = config.secrets.mail-sasl-passwd.path;
      valias = config.secrets.mail-postfix.path;
      vaccounts = config.secrets.mail-postfix.path;
      virtual = config.secrets.mail-postfix.path;
      denied_recipient = pkgs.writeText "denied_recipient" "";
      reject_senders = pkgs.writeText "reject_senders" "";
      reject_recipient = pkgs.writeText "reject_recipient" "";
    };

    submissionOptions = mkForce {
      smtpd_tls_security_level = "encrypt";
      smtpd_sasl_auth_enable = "yes";
      smtpd_sasl_type = "dovecot";
      smtpd_sasl_path = "/run/dovecot2/auth";
      smtpd_sasl_security_options = "noanonymous";
      smtpd_sasl_local_domain = "$myhostname";
      smtpd_client_restrictions = "permit_sasl_authenticated,reject";
      smtpd_sender_login_maps = "hash:/etc/postfix/vaccounts";
      smtpd_sender_restrictions = "reject_sender_login_mismatch";
      smtpd_recipient_restrictions = "reject_non_fqdn_recipient,reject_unknown_recipient_domain,permit_sasl_authenticated,reject";
      cleanup_service_name = "submission-header-cleanup";
    };
    submissionsOptions = mkForce (config.services.postfix.submissionOptions);

    settings.main = {
      smtp_sasl_auth_enable = true;
      smtp_sasl_password_maps = "hash:/etc/postfix/sasl_passwd";
      smtp_sasl_security_options = "noanonymous";
      smtp_sasl_tls_security_options = "noanonymous";
      smtp_sasl_mechanism_filter = "AUTH LOGIN";
      smtp_tls_security_level = mkForce "encrypt";
      relayhost = [ "[smtp-relay.brevo.com]:587" ];

      virtual_alias_maps = mkForce "hash:/etc/postfix/virtual";
      virtual_mailbox_maps = mkForce "hash:/etc/postfix/valias";

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
