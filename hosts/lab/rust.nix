# / is small, so kache's store and every user's cargo target directory live on the encrypted
# data disk
{ config, lib, ... }:
let
  kacheStore = "/mnt/encrypted/kache";
  cargoTargets = "/mnt/encrypted/cargo-target";
in
{
  # kache reads one store path for every user, and r3dlust is the one who builds rust on lab
  services.kache.settings.cache.local_store = kacheStore;

  systemd.tmpfiles.rules = [
    "d ${kacheStore} 0700 r3dlust users - -"
    "d ${cargoTargets} 0755 root root - -"
  ]
  ++ map (name: "d ${cargoTargets}/${name} 0755 ${name} ${config.users.users.${name}.group} - -") (
    lib.attrNames config.home-manager.users
  );

  home-manager.sharedModules = [
    (
      { config, ... }:
      {
        home.file.".cargo/config.toml".text = lib.mkAfter ''
          target-dir = "${cargoTargets}/${config.home.username}"
        '';
      }
    )
  ];
}
