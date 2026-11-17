{
  config,
  lib,
  pkgs,
  nixos-mailserver,
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
  imports = [
    nixos-mailserver.nixosModules.default
    oxi.nixosModules.default
  ];

  cloudflare.dns = {
    "mail.r3dlust.com".a = { };
    "r3dlust.com" = {
      mx = [
        {
          exchange = "mail.r3dlust.com";
          priority = 10;
        }
      ];
      txt = [
        "v=spf1 include:rp.oracleemaildelivery.com ~all"
        "brevo-code:5ba0154555d819372c9dfa33dfae7ba6"
      ];
    };
    "_dmarc.r3dlust.com".txt = [ "v=DMARC1; p=none; rua=mailto:rua@dmarc.brevo.com" ];
    "mail._domainkey.r3dlust.com".txt = [
      "k=rsa;p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDeMVIzrCa3T14JsNY0IRv5/2V1/v2itlviLQBwXsa7shBD6TrBkswsFUToPyMRWC9tbR/5ey0nRBH0ZVxp+lsmTxid2Y2z+FApQ6ra2VsXfbJP3HE6wAO0YTVEJt1TmeczhEd2Jiz/fcabIISgXEdSpTYJhb0ct0VJRxcg4c8c7wIDAQAB"
    ];
  };

  networking.certificates."mail.r3dlust.com" = {
    enable = true;
    group = "mail-certs";
    users = [
      "caddy"
    ];
  };

  secrets = {
    mail-sasl-passwd.file = ./sasl_passwd.age;

    mail-dovecot.file = ./dovecot.age;
    mail-postfix.file = ./postfix.age;
  };

  mailserver = enabled {
    stateVersion = 5;
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
      ${config.networking.certificates."mail.r3dlust.com".paths.caddy}

      header {
        X-Content-Type-Options nosniff
        X-Frame-Options SAMEORIGIN
        Referrer-Policy same-origin
      }

      reverse_proxy http://127.0.0.1:${toString config.services.oxi.port}
    '';
  };
}
