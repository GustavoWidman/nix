{
  config,
  pkgs,
  lib,
  ...
}:

{
  secrets = {
    mailserver-admin-password = {
      file = ./secrets/mailserver-admin-password.age;
      owner = "mail";
      group = "mail";
      mode = "400";
    };

    # Relay password for Brevo
    smtp-relay-password = {
      file = ./secrets/smtp-relay-password.age;
      owner = "mail";
      group = "mail";
      mode = "400";
    };

    # User passwords (add more as needed)
    mail-user-passwords = {
      file = ./secrets/mail-user-passwords.age;
      owner = "mail";
      group = "mail";
      mode = "400";
    };
  };

  # Simple NixOS Mailserver configuration
  mailserver = {
    enable = true;

    # Basic configuration
    fqdn = "mail.${config.networking.domain}";
    domains = [ config.networking.domain ];

    # SSL/TLS Configuration using ACME
    certificateScheme = "acme-nginx"; # or "acme" if not using nginx

    # Enable services
    enableImap = true;
    enableImapSsl = true;
    enablePop3 = true;
    enablePop3Ssl = true;
    enableSubmission = true;
    enableSubmissionSsl = true;

    # Mailbox configuration
    mailboxes = {
      Trash = {
        auto = "no";
        specialUse = "Trash";
      };
      Junk = {
        auto = "subscribe";
        specialUse = "Junk";
      };
      Drafts = {
        auto = "subscribe";
        specialUse = "Drafts";
      };
      Sent = {
        auto = "subscribe";
        specialUse = "Sent";
      };
      Archive = {
        auto = "subscribe";
        specialUse = "Archive";
      };
    };

    # Login accounts - using hashedPasswordFile for agenix integration
    loginAccounts = {
      "admin@${config.networking.domain}" = {
        hashedPasswordFile = config.secrets.mailserver-admin-password.path;
        aliases = [ "postmaster@${config.networking.domain}" ];
        quota = "10G";
      };

      # Add more user accounts as needed
      # "user@${mailDomain}" = {
      #   hashedPasswordFile = "${secretsPath}/mail-user-passwords";
      #   quota = "5G";
      # };
    };

    # Relay host configuration (Brevo SMTP)
    # relayHost = "smtp-relay.brevo.com";
    # relayPort = 587;
    # relayAuthUser = "6b3742001@smtp-brevo.com";
    # relayPasswordFile = builtins.toString config.secrets.smtp-relay-password.path;

    # Virus and spam scanning
    virusScanning = true; # Enables ClamAV

    # DKIM signing
    dkimSigning = true;
    dkimSelector = "mail";
    dkimKeyDirectory = "/var/lib/rspamd/dkim";

    # Full text search
    fullTextSearch = {
      enable = true;
      autoIndex = true;
      indexAttachments = true;
    };

    # Message size limits
    messageSizeLimit = "25000000"; # 25MB in bytes

    # Mailbox format

    # Monitoring and maintenance
    monitoring = {
      enable = true;
      alertAddress = "admin@${config.networking.domain}";
    };
  };

  # Additional Postfix configuration
  services.postfix = {
    config = {
      # Security settings matching your Docker config
      smtpd_tls_security_level = "may";
      smtp_tls_security_level = "may";
      smtpd_tls_protocols = "!SSLv2, !SSLv3, !TLSv1, !TLSv1.1";
      smtp_tls_protocols = "!SSLv2, !SSLv3, !TLSv1, !TLSv1.1";

      # Additional restrictions
      smtpd_recipient_restrictions = lib.concatStringsSep ", " [
        "permit_sasl_authenticated"
        "permit_mynetworks"
        "reject_unauth_destination"
        "reject_unauth_pipelining"
        "reject_invalid_helo_hostname"
        "reject_non_fqdn_helo_hostname"
        "reject_non_fqdn_sender"
        "reject_non_fqdn_recipient"
        "reject_unknown_sender_domain"
        "reject_unknown_recipient_domain"
      ];

      # Logging
      maillog_file = "/var/log/mail/mail.log";
    };
  };

  # Dovecot additional configuration
  services.dovecot2 = {
    enableQuota = true;
    quotaGlobalPerUser = "10G";

    # Additional protocols
    protocols = [
      "imap"
      "pop3"
      "lmtp"
      "sieve"
    ];

    # Plugin configuration
    pluginSettings = {
      sieve = "~/.dovecot.sieve";
      sieve_dir = "~/sieve";
      sieve_global_path = "/var/lib/dovecot/sieve/default.sieve";

      # FTS (Full Text Search) configuration
      fts = "lucene";
      fts_lucene = "whitespace_chars=@.";
    };
  };

  # ClamAV configuration
  services.clamav = {
    daemon.enable = true;
    updater = {
      enable = true;
      interval = "daily";
      frequency = 12; # Check every 12 hours
    };
  };

  # Roundcube webmail
  services.roundcube = {
    enable = true;
    hostName = "webmail.${config.networking.domain}";

    # Database configuration
    database = {
      host = "localhost";
      dbname = "roundcube";
      username = "roundcube";
      passwordFile = builtins.toString config.secrets.mail-user-passwords.path;
    };

    # Extra configuration
    extraConfig = ''
      $config['smtp_server'] = 'tls://mail.${config.networking.domain}';
      $config['smtp_port'] = 587;
      $config['smtp_user'] = '%u';
      $config['smtp_pass'] = '%p';
      $config['smtp_auth_type'] = 'PLAIN';

      $config['default_host'] = 'tls://mail.${config.networking.domain}';
      $config['default_port'] = 143;

      $config['des_key'] = 'rcmail-!24ByteDESkey*Str';
      $config['cipher_method'] = 'AES-256-CBC';
      $config['force_https'] = true;

      $config['skin'] = 'elastic';

      // Plugins
      $config['plugins'] = array(
        'archive',
        'zipdownload',
        'newmail_notifier',
        'managesieve',
        'password',
        'emoticons',
        'enigma'
      );
    '';

    plugins = [
      "archive"
      "zipdownload"
      "newmail_notifier"
      "managesieve"
      "password"
    ];
  };

  # PostgreSQL for Roundcube
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;

    ensureDatabases = [ "roundcube" ];
    ensureUsers = [
      {
        name = "roundcube";
        ensureDBOwnership = true;
      }
    ];

    authentication = ''
      local roundcube roundcube md5
    '';
  };

  # Firewall rules
  networking.firewall.allowedTCPPorts = [
    25 # SMTP
    80 # HTTP (for ACME)
    110 # POP3
    143 # IMAP
    443 # HTTPS
    465 # SMTPS
    587 # Submission
    993 # IMAPS
    995 # POP3S
    4190 # ManageSieve
  ];

  # System users and groups
  users.users.mail = {
    isSystemUser = true;
    group = "mail";
    description = "Mail server user";
  };

  users.groups.mail = { };

  # Log rotation
  services.logrotate = {
    enable = true;
    settings = {
      "/var/log/mail/mail.log" = {
        frequency = "weekly";
        rotate = 52;
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
        postrotate = "systemctl reload postfix dovecot2";
      };
    };
  };

  # Time zone
  time.timeZone = "America/Sao_Paulo";

  # Enable automatic updates for virus definitions
  systemd.services.clamav-updater = {
    serviceConfig = {
      PrivateTmp = "yes";
      PrivateDevices = "yes";
    };
  };
}
