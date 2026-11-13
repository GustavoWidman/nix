# a tls certificate for this machine's tailnet name, from tailscaled, which
# orders it from let's encrypt and renews it. tailscaled issues one for the
# machine's own magicdns name only, so a machine has at most one.
#
# tailscale-cert writes it before the services that read it start, and daily
# after; `tailscale cert` hands back the cached certificate until it nears
# expiry. when the files change, the services that read them reload, or
# restart when they cannot reload.
#
# the files belong to a group. the services in reloadServices join it through
# SupplementaryGroups, so adding or removing one changes its unit, and the
# switch restarts it with or without the group. a user in `users` joins it in
# /etc/group, which a process reads only when it starts: one that is already
# running keeps the groups it started with.
#
# tests/tailscale-certificate.nix runs it in a vm.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    genAttrs
    getExe
    mkEnableOption
    mkIf
    mkOption
    removeSuffix
    types
    ;

  cfg = config.tailscale.certificate;

  dir = "/var/lib/tailscale-cert";
  services = map (removeSuffix ".service") cfg.reloadServices;
in
{
  options.tailscale.certificate = {
    enable = mkEnableOption "a tls certificate for this machine's tailnet name";

    domain = mkOption {
      type = types.str;
      default = "${config.networking.hostName}.tail4a3ea.ts.net";
      defaultText = "<hostName>.tail4a3ea.ts.net";
      description = "This machine's magicdns name, the only name tailscaled issues a certificate for.";
    };

    group = mkOption {
      type = types.str;
      default = "tailscale-cert";
      description = "The group that can read the certificate and its key.";
    };

    users = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Users added to `group`, so they can read the certificate and its key. A running process keeps the groups it started with; give a service access through `reloadServices` instead.";
    };

    reloadServices = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "caddy" ];
      description = "Services that read the certificate: they join `group`, start after tailscale-cert, and get `systemctl try-reload-or-restart` when the certificate changes.";
    };

    paths = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      default = {
        # the certificate and its chain
        cert = "${dir}/cert.pem";
        key = "${dir}/key.pem";
        caddy = "tls ${dir}/cert.pem ${dir}/key.pem";
      };
      description = "Where the certificate is: `cert` (with its chain), `key`, and `caddy`, a caddy tls directive.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "tailscale.certificate needs tailscaled: set tailscale.enable.";
      }
    ];

    users.groups.${cfg.group} = { };
    users.users = genAttrs cfg.users (_: {
      extraGroups = [ cfg.group ];
    });

    systemd.services =
      genAttrs services (_: {
        wants = [ "tailscale-cert.service" ];
        after = [ "tailscale-cert.service" ];
        serviceConfig.SupplementaryGroups = [ cfg.group ];
      })
      // {
        tailscale-cert = {
          description = "TLS certificate for ${cfg.domain} from tailscaled";
          wants = [
            "network-online.target"
            "tailscaled.service"
          ];
          after = [
            "network-online.target"
            "tailscaled.service"
          ];
          serviceConfig.Type = "oneshot";
          script = ''
            new=$(mktemp -d)
            trap 'rm -rf "$new"' EXIT
            ${getExe config.services.tailscale.package} cert \
              --cert-file "$new/cert.pem" --key-file "$new/key.pem" ${cfg.domain}

            install -d -m 0750 -g ${cfg.group} ${dir}
            if ${pkgs.diffutils}/bin/cmp -s "$new/cert.pem" ${cfg.paths.cert} \
              && ${pkgs.diffutils}/bin/cmp -s "$new/key.pem" ${cfg.paths.key}; then
              exit 0
            fi
            # renamed into place, so a reader never sees half a file
            for file in key.pem cert.pem; do
              install -m 0640 -g ${cfg.group} "$new/$file" ${dir}/.$file.new
              mv -f ${dir}/.$file.new ${dir}/$file
            done

            # a service waiting to start reads the new files anyway, and
            # queueing a reload behind its start would conflict with it
            for service in ${toString services}; do
              if systemctl is-active --quiet "$service.service"; then
                systemctl try-reload-or-restart --no-block "$service.service"
              fi
            done
          '';
        };
      };

    systemd.timers.tailscale-cert = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };
  };
}
