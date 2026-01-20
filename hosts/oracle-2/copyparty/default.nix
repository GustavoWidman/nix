{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    enabled
    ;
in
{
  networking.certificates."files.r3dlust.com" = {
    enable = true;
    group = "caddy-certs";
    users = [
      "caddy"
    ];

    postRun = ''
      systemctl reload-or-restart caddy.service
    '';
  };

  secrets.copyparty-password = {
    file = ./password.age;
    owner = config.services.copyparty.user;
    group = config.services.copyparty.group;
  };

  fileSystems."/mnt/lab" = {
    device = "lab:/mnt/encrypted";

    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noatime"
      "vers=4.2"
      "_netdev" # Wait for network before mounting
      "soft" # Don't hang forever if server is unreachable
      "timeo=14" # Timeout quickly (1.4 seconds)
      "retrans=2" # Retry twice
    ];
  };

  systemd.services."mnt-lab.mount" = {
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
  };

  services.copyparty = enabled {
    package = pkgs.copyparty-full;

    user = "copyparty";
    group = "copyparty";

    settings = {
      name = "file hosting for r3dlust";
      i = "127.0.0.1";
      p = [ 46971 ];

      # Protocol servers
      # ftp = 3921; # FTP server
      # ftps = 3990; # FTP with TLS
      # sftp = 3922; # SFTP server

      # Enable file indexing and search
      e2dsa = true;
      e2ts = true;

      # Enable various nice features
      rss = true; # RSS feeds for folders
      ver = true; # File versioning

      # UI and theme
      theme = 2; # Flat pm-monokai theme (modern dark theme)
      grid = true; # Default to grid view for images

      # Reverse proxy settings (for Caddy)
      xff-src = "127.0.0.1"; # Trust X-Forwarded-For from localhost
      xff-hdr = "X-Forwarded-For";
      rproxy = 1; # Running behind reverse proxy

      # Security settings
      no-robots = true; # Tell search engines not to index
      force-js = true; # Require JavaScript (harder to crawl)
      vague-403 = true; # Return 404 instead of 403 (security through obscurity)
      ban-pw = "24,9,3600"; # Ban after 9 failed password attempts in 1 hour for 24 hours
      ah-alg = "argon2"; # Enable password hashing
      ah-salt = "a5knE+xT1x5dWZJBODb+eRZp";
      http-only = true; # Configure HTTPs in Caddy

      # Enable shares feature for per-file sharing
      shr = "/shares"; # Virtual folder for temporary shares

      # Hide recent uploads from everyone except admins
      ups-who = 1; # 0=nobody, 1=admins only, 2=everyone (default)
      ups-when = false; # Only admins see upload times

      # Performance and features
      dedup = true; # Enable deduplication via symlinks
      hardlink = true; # Use hardlinks instead of symlinks but allow fallback to symlinks (safer)

      # Do not allow config reload without restart (more declarative)
      no-reload = true;
    };

    accounts.admin.passwordFile = config.secrets.copyparty-password.path;

    volumes = {
      # Main volume - your encrypted drive
      "/" = {
        path = "/srv/copyparty";
        access = {
          A = "admin";
        };
        flags = {
          e2d = true;
          e2t = true;
          fk = 8;
          scan = 300;
        };
      };

      "/nextcloud" = {
        path = "/mnt/lab/oracle-1";
        access = {
          A = "admin";
        };
        flags = {
          e2d = true;
          e2t = true;
          fk = 8;
          scan = 300;
        };
      };

      "/lab" = {
        path = "/mnt/lab/files";
        access = {
          A = "admin";
        };
        flags = {
          e2d = true;
          e2t = true;
          fk = 8;
          scan = 300;
        };
      };
    };

    openFilesLimit = 8192;
  };

  systemd.tmpfiles.rules = [
    "d /srv/copyparty 0755 copyparty copyparty -"
  ];

  systemd.services.copyparty = {
    after = [ "mnt-lab.mount" ];
    requires = [ "mnt-lab.mount" ];
  };

  services.caddy.virtualHosts."files.r3dlust.com".extraConfig = ''
    ${config.networking.certificates."files.r3dlust.com".paths.caddy}

    reverse_proxy /* {
      to http://127.0.0.1:46971
    }
  '';
}
