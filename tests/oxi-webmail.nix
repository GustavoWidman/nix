{ flake }:
let
  inherit (flake) lib;
  cfg = flake.nixosConfigurations.oracle-2.config;
  oxi = cfg.services.oxi;
  unit = cfg.systemd.services.oxi;
  proxy = cfg.services.caddy.virtualHosts."mail.r3dlust.com".extraConfig;
  checks = {
    enabled = oxi.enable;
    loopbackOnly = oxi.host == "127.0.0.1" && oxi.port == 37993;
    noPublicBackendPort = !(builtins.elem oxi.port cfg.networking.firewall.allowedTCPPorts);
    imapTls = oxi.imapHost == "mail.r3dlust.com" && oxi.imapPort == 993 && oxi.tlsEnabled;
    smtpStartTls = oxi.smtpHost == "mail.r3dlust.com" && oxi.smtpPort == 587 && oxi.tlsEnabled;
    production = unit.environment.ENVIRONMENT == "production";
    trustedProxyOnly = unit.environment.TRUSTED_PROXIES == "127.0.0.1";
    staticRootMatches = (oxi.package.oxiBasePath or null) == "" && oxi.basePath == null;
    privateState =
      unit.serviceConfig.StateDirectory == "oxi"
      && unit.serviceConfig.StateDirectoryMode == "0700"
      && unit.serviceConfig.UMask == "0077";
    unprivileged =
      unit.serviceConfig.User == "oxi"
      && unit.serviceConfig.NoNewPrivileges
      && unit.serviceConfig.ProtectSystem == "strict"
      && unit.serviceConfig.ProtectHome;
    proxyEnabled =
      lib.hasInfix "reverse_proxy http://127.0.0.1:37993" proxy
      && !(lib.hasInfix "respond \"Webmail is disabled.\" 503" proxy);
    roundcubeDisabled = !(cfg.virtualisation.arion.projects ? roundcube);
    otherHostsUnchanged =
      !flake.nixosConfigurations.lab.config.services.oxi.enable
      && !flake.nixosConfigurations.oracle-1.config.services.oxi.enable;
    nixosAssertionsPass = builtins.all (a: a.assertion) cfg.assertions;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: ok: !ok) checks);
in
assert lib.assertMsg (
  failures == [ ]
) "Oxi regression checks failed: ${lib.concatStringsSep ", " failures}";
checks
