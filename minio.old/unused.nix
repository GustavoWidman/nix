{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) enabled;
in
{
  secrets.minio-credentials.file = ./credentials.age;
  services.minio = enabled {
    browser = false;

    dataDir = [ "/mnt/encrypted" ];

    listenAddress = "100.122.90.22:9000";

    rootCredentialsFile = config.secrets.minio-credentials.path;
  };

  systemd.services.minio = {
    after = [ "mnt-encrypted.mount" ];
    requires = [ "mnt-encrypted.mount" ];

    # Additional performance tuning
    serviceConfig = {
      LimitNOFILE = 65536;
      User = "minio";
      Group = "minio";
    };

  };

  users.users.minio = {
    isSystemUser = true;
    group = "minio";
    home = "/var/lib/minio";
    createHome = true;
  };
  users.groups.minio = { };

  systemd.tmpfiles.rules = [
    "Z /mnt/encrypted - minio minio - -"
  ];

  environment.systemPackages = with pkgs; [
    minio-client
  ];
}
