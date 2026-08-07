{
  config,
  lib,
  pkgs,
  ...
}:
let
  dataDir = "/mnt/encrypted/rustfs";
  apiPort = 9000;
in
{
  secrets.rustfs-environment = {
    file = ./environment.env.age;
    owner = config.services.rustfs.user;
    group = config.services.rustfs.group;
    mode = "0400";
  };

  services.rustfs = {
    enable = true;
    environmentFile = config.secrets.rustfs-environment.path;
    settings = {
      RUSTFS_VOLUMES = dataDir;
      RUSTFS_ADDRESS = ":${toString apiPort}";
      RUSTFS_CONSOLE_ENABLE = "false";
      RUSTFS_REGION = "us-east-1";
      RUST_LOG = "warn";
    };
  };

  systemd.tmpfiles.settings."10-rustfs".${dataDir}.d.mode = "0700";

  systemd.services.rustfs = {
    after = [
      "mnt-encrypted.mount"
      "tailscaled.service"
    ];
    requires = [
      "mnt-encrypted.mount"
      "tailscaled.service"
    ];
    preStart = lib.mkBefore ''
      if ! ${pkgs.util-linux}/bin/mountpoint --quiet /mnt/encrypted; then
        echo "/mnt/encrypted is not mounted" >&2
        exit 1
      fi
    '';
    serviceConfig = {
      UMask = "0077";
      CapabilityBoundingSet = "";
      LockPersonality = true;
      ProtectHostname = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      ProtectSystem = "strict";
      ReadWritePaths = [ dataDir ];
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      RestrictNamespaces = true;
      SystemCallArchitectures = "native";
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ apiPort ];
}
