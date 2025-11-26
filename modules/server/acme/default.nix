{
  config,
  lib,
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
in
{
  options.networking.certificates = mkOption {
    type = attrsOf (
      submodule (
        { name, ... }:
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

            postRun = mkOption {
              type = str;
              default = "";
              description = "Commands to run after certificate renewal";
            };

            reloadServices = mkOption {
              type = listOf str;
              default = [ ];
              description = "The list of systemd services to call `systemctl try-reload-or-restart` on.";
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

  config = {
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
            postRun = certCfg.postRun;
            reloadServices = certCfg.reloadServices;
            extraDomainNames =
              ([ certCfg.wildcard ] |> filter id |> map (_: "*.${domain}")) ++ certCfg.extraDomainNames;
          }
        );
    };
  };
}
