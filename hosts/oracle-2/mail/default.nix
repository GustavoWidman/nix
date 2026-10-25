{
  config,
  lib,
  pkgs,
  oxi,
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

    accounts = { };

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
      chown dovecot2:dovecot2 /run/dovecot2/passwd /run/dovecot2/userdb
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

  systemd.services.postfix = {
    restartTriggers = [
      config.secrets.mail-postfix.path
      config.secrets.mail-sasl-passwd.path
    ];

    preStart = ''
      ${pkgs.postfix}/bin/postmap /var/lib/postfix/conf/valias
      ${pkgs.postfix}/bin/postmap /var/lib/postfix/conf/vaccounts
      ${pkgs.postfix}/bin/postmap /var/lib/postfix/conf/virtual
      ${pkgs.postfix}/bin/postmap /var/lib/postfix/conf/sasl_passwd
    '';
  };

  # Oxi uses the existing mail accounts; no shared application password or
  # additional agenix secret is needed. Keep the old Roundcube volumes intact.
  services.oxi = enabled {
    package = pkgs.callPackage ../../../packages/oxi { upstream = oxi; };
    host = "127.0.0.1";
    port = 37993;
    imapHost = "mail.r3dlust.com";
    imapPort = 993;
    smtpHost = "mail.r3dlust.com";
    smtpPort = 587; # Oxi uses required STARTTLS on this port.
    tlsEnabled = true;
    sessionTimeoutHours = 12;
  };

  systemd.services.oxi = {
    after = [
      "dovecot.service"
      "postfix.service"
    ];
    environment.TRUSTED_PROXIES = "127.0.0.1";
    serviceConfig = {
      StateDirectory = "oxi";
      StateDirectoryMode = "0700";
      UMask = "0077";
    };
  };

  services.caddy.virtualHosts."mail.r3dlust.com" = {
    extraConfig = ''
      tls ${config.networking.certificates."mail.r3dlust.com".paths.fullchain} ${
        config.networking.certificates."mail.r3dlust.com".paths.key
      }

      header {
        X-Content-Type-Options nosniff
        X-Frame-Options SAMEORIGIN
        Referrer-Policy same-origin
      }

      reverse_proxy http://127.0.0.1:${toString config.services.oxi.port}
    '';
  };
}
