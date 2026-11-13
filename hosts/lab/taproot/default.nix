{
  config,
  taproot,
  ...
}:
let
  cfg = config.services.taproot;
  certificate = config.tailscale.certificate;

  auths = cfg.settings.oauth.auth-dir;

  # cliproxyapi, which taproot replaced, kept its OAuth credentials at the top
  # of its data directory.
  cliproxyapiAuths = "/var/lib/cliproxyapi";
in
{
  imports = [ taproot.nixosModules.default ];

  secrets.taproot-settings = {
    file = ./settings.yaml.age;
    mode = "400";
  };

  services.taproot = {
    enable = true;
    # lab's address from `tailscale ip -4`; taproot listens only there.
    tailscale.address = "100.122.90.22";
    openFirewall = true;
    inherit (config.time) timeZone;

    settings = {
      # Clients call https://lab.tail4a3ea.ts.net:8317.
      server.tls = {
        enable = true;
        inherit (certificate.paths) cert key;
      };
      routing.retry = {
        request-retry = 3;
        max-retry-interval = 30;
      };
    };

    # api-keys.gemini: the Gemini API keys.
    settingsFiles = [ config.secrets.taproot-settings.path ];

    # Seeds taproot.yaml on the first start only; the dashboard owns it after.
    taprootSettings.access = {
      devices =
        map
          (
            device:
            device
            // {
              proxy = true;
              admin = true;
            }
          )
          [
            {
              id = "nKyFykCKS821CNTRL";
              name = "altar";
            }
            {
              id = "nKhSFUJHxn11CNTRL";
              name = "laptop-mac";
            }
            {
              id = "nCDFhHeGR411CNTRL";
              name = "desktop-nixos";
            }
            {
              id = "ngRnRk3HJE11CNTRL";
              name = "desktop-windows";
            }
            {
              id = "nq9kwhTtbf11CNTRL";
              name = "phone-gustavo";
            }
          ];
      # honcho's containers call taproot from the honcho bridge, outside
      # Tailscale, and docker gives a restarted container a new address there.
      addresses = [
        {
          cidr = "172.19.0.0/16";
          note = "honcho containers";
        }
      ];
    };
  };

  # taproot reads the certificate only at start, so a renewal restarts it.
  tailscale.certificate = {
    enable = true;
    reloadServices = [ "taproot" ];
  };

  # Copies cliproxyapi's OAuth credentials, its auth files and Codex refresh
  # journal, into taproot's auth directory before taproot's first start. It
  # runs only while that directory does not exist, and taproot does not start
  # if the copy fails, so taproot never starts without them.
  systemd.services.taproot-import-cliproxyapi = {
    description = "Copy cliproxyapi's OAuth credentials into taproot";
    before = [ "taproot.service" ];
    requiredBy = [ "taproot.service" ];
    unitConfig.ConditionPathExists = [
      cliproxyapiAuths
      "!${auths}"
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      install -d -m 0700 -o ${cfg.user} -g ${cfg.group} ${cfg.dataDir}
      staging=${auths}.import
      rm -rf "$staging"
      install -d -m 0700 "$staging"
      shopt -s nullglob
      for file in ${cliproxyapiAuths}/*.json; do
        cp -p "$file" "$staging/"
      done
      if [ -d ${cliproxyapiAuths}/.codex-refresh ]; then
        cp -rp ${cliproxyapiAuths}/.codex-refresh "$staging/"
      fi
      chown -R ${cfg.user}:${cfg.group} "$staging"
      chmod -R go-rwx "$staging"
      mv "$staging" ${auths}
    '';
  };
}
