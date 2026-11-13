{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    map
    mapAttrs
    mapAttrsToList
    filterAttrs
    genAttrs
    flatten
    unique
    groupBy
    mkOption
    mkEnableOption
    mkDefault
    filter
    id
    ;

  inherit (lib.types)
    attrsOf
    str
    bool
    listOf
    path
    submodule
    ;

  enabledCertificates = config.networking.certificates |> filterAttrs (name: cert: cert.enable);

  getCertificateGroups = enabledCertificates |> mapAttrsToList (name: cert: cert.group) |> unique;

  getUserGroupAssignments =
    enabledCertificates
    |> mapAttrsToList (
      domain: certCfg:
      certCfg.users
      |> map (user: {
        inherit user;
        group = certCfg.group;
      })
    )
    |> flatten;

  getGroupedUserAssignments = getUserGroupAssignments |> groupBy (assignment: assignment.user);

  # Certificates Caddy reads, by domain.
  caddyCertificates =
    enabledCertificates |> filterAttrs (domain: certCfg: lib.elem "caddy" certCfg.users) |> lib.attrNames;

  # A switch reloads the units that already run before it starts new ones, so Caddy
  # reloads into a config naming a new certificate before acme-<domain>.service has
  # written even its placeholder, and the reload fails. Activation runs before both, so it
  # writes a one-day self-signed placeholder for every certificate that has no files yet.
  # acme-<domain>.service replaces it, and lego still orders the real certificate: it
  # tracks its own state, not these files.
  placeholderScript =
    enabledCertificates
    |> mapAttrsToList (
      domain: certCfg:
      let
        dir = "/var/lib/acme/${domain}";
        openssl = lib.getExe pkgs.openssl;
      in
      ''
        if [ ! -e ${dir}/cert.pem ]; then
          install -d -m 750 -o acme -g ${certCfg.group} ${dir}
          ${openssl} req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
            -days 1 -subj /CN=${domain} -addext subjectAltName=DNS:${domain} \
            -keyout ${dir}/key.pem -out ${dir}/cert.pem 2>/dev/null
          cp ${dir}/cert.pem ${dir}/fullchain.pem
          cp ${dir}/cert.pem ${dir}/chain.pem
          cat ${dir}/key.pem ${dir}/cert.pem > ${dir}/full.pem
          chown acme:${certCfg.group} ${dir}/*.pem
          chmod 640 ${dir}/*.pem
        fi
      ''
    )
    |> lib.concatStrings;
in
{
  options.networking.certificates = mkOption {
    type = attrsOf (
      submodule (
        cert@{ name, ... }:
        {
          options = {
            enable = mkEnableOption "certificate generation for ${name}";

            email = mkOption {
              type = str;
              default = "admin@r3dlust.com";
              description = "Email for ACME registration";
            };

            wildcard = mkOption {
              type = bool;
              default = false;
              description = "Whether to include wildcard certificate (*.domain.com)";
            };

            extraDomainNames = mkOption {
              type = listOf str;
              default = [ ];
              description = "Additional domain names to include in the certificate.";
            };

            dnsProvider = mkOption {
              type = str;
              default = "cloudflare";
              description = "DNS provider for DNS-01 challenge";
            };

            dnsResolver = mkOption {
              type = str;
              default = "1.1.1.1:53";
              description = "DNS resolver for DNS-01 challenge";
            };

            environmentFile = mkOption {
              type = path;
              default = config.secrets.acme-environment.path;
              description = "Path to DNS provider credentials file";
            };

            group = mkOption {
              type = str;
              default = "acme";
              description = "Group that can read the certificates";
            };

            users = mkOption {
              type = listOf str;
              default = [ ];
              description = "List of users who can access the certificate files. All users in this list will be added to the group specified in 'group', defaulting to 'acme'.";
            };

            reloadServices = mkOption {
              type = listOf str;
              default = cert.config.users |> map (user: "${user}.service");
              defaultText = lib.literalExpression ''users |> map (user: "''${user}.service")'';
              description = "The systemd services to `systemctl try-reload-or-restart` after a renewal. Every user in `users` runs a service of the same name that reads the certificate, so they default to those.";
            };

            paths = mkOption {
              type = submodule {
                options = {
                  cert = mkOption {
                    type = str;
                    default = "/var/lib/acme/${name}/cert.pem";
                    readOnly = true;
                    description = "Path to certificate file";
                  };

                  key = mkOption {
                    type = str;
                    default = "/var/lib/acme/${name}/key.pem";
                    readOnly = true;
                    description = "Path to private key file";
                  };

                  fullchain = mkOption {
                    type = str;
                    default = "/var/lib/acme/${name}/fullchain.pem";
                    readOnly = true;
                    description = "Path to full certificate chain";
                  };

                  full = mkOption {
                    type = str;
                    default = "/var/lib/acme/${name}/full.pem";
                    readOnly = true;
                    description = "Path to full certificate (cert + key)";
                  };

                  caddy = mkOption {
                    type = str;
                    default = "tls /var/lib/acme/${name}/cert.pem /var/lib/acme/${name}/key.pem";
                    readOnly = true;
                    description = "Pre-formatted Caddy TLS directive";
                  };
                };
              };
              default = { };
              readOnly = true;
              description = "Certificate file paths";
            };
          };
        }
      )
    );
    default = { };
    description = "Certificate configurations";
  };

  config = lib.optionalAttrs (!isDarwin) {
    secrets.acme-environment.file = ./environment.env.age;

    users.groups = genAttrs getCertificateGroups (group: { });

    users.users =
      getGroupedUserAssignments
      |> mapAttrs (
        user: assignments: {
          extraGroups = assignments |> map (a: a.group) |> unique;
        }
      );

    networking.domain = mkDefault "r3dlust.com";

    system.activationScripts.acme-placeholders = {
      deps = [
        "users"
        "groups"
      ];
      text = placeholderScript;
    };

    # On boot, start Caddy once its certificates exist, as useACMEHost would.
    systemd.services.caddy = lib.mkIf (caddyCertificates != [ ]) {
      wants = caddyCertificates |> map (domain: "acme-${domain}.service");
      after = caddyCertificates |> map (domain: "acme-${domain}.service");
    };

    security.acme = {
      acceptTerms = true;

      defaults = {
        environmentFile = config.secrets.acme-environment.path;
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1:53";
        email = "security@${config.networking.domain}";
      };

      certs =
        enabledCertificates
        |> mapAttrs (
          domain: certCfg: {
            email = certCfg.email;
            dnsProvider = certCfg.dnsProvider;
            environmentFile = certCfg.environmentFile;
            dnsResolver = certCfg.dnsResolver;
            group = certCfg.group;
            reloadServices = certCfg.reloadServices;
            extraDomainNames =
              ([ certCfg.wildcard ] |> filter id |> map (_: "*.${domain}")) ++ certCfg.extraDomainNames;
          }
        );
    };
  };
}
