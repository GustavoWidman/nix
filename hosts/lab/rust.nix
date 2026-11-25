# / is small, so kache's store and every user's cargo target directory live on the encrypted
# data disk
{ config, lib, ... }:
let
  kacheStore = "/mnt/encrypted/kache";
  kacheOwner = "r3dlust";
  cargoTargets = "/mnt/encrypted/cargo-target";
in
{
  # kache reads one store path for every user, and r3dlust is the one who builds rust on lab
  services.kache.settings.cache.local_store = kacheStore;

  # the daemon is a user service, so every lingering user's manager starts it; anyone but the
  # store's owner can't take its run lock, exits, and is restarted every 5 s without end. their
  # builds still compile, uncached, through the wrapper
  systemd.user.services.kache.unitConfig.ConditionUser = kacheOwner;

  systemd.tmpfiles.rules = [
    "d ${kacheStore} 0700 ${kacheOwner} users - -"
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
