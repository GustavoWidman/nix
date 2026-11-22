{
  config,
  lib,
  pkgs,
  ...
}:
let
  kacheCacheDir = "/mnt/encrypted/oracle/kache";
  cargoTargetDir = "/mnt/encrypted/oracle/cargo-target";
in
{
  services.kache.settings.cache.local_store = kacheCacheDir;

  users.groups.kache = {
    gid = 987;
  };
  users.groups.oracle = {
    gid = 991;
  };

  systemd.tmpfiles.rules = [
    "d ${kacheCacheDir} 2775 oracle kache - -"
    "d ${cargoTargetDir} 0755 oracle oracle - -"
    "d ${cargoTargetDir}/oracle 0755 oracle oracle - -"
    "d /mnt/encrypted/oracle/misc 0755 oracle oracle - -"
    "d ${cargoTargetDir}/r3dlust 0755 r3dlust users - -"
  ];

  # add oracle as a home-manager user
  home-manager.users.oracle = { };

  # add oracle's user to the "docker" group
  users.users.oracle = {
    uid = 993;
    isSystemUser = true;
    group = "oracle";
    home = "/home/oracle";
    createHome = true;
    shell = pkgs.bash;
    extraGroups = [
      "docker"
      "kache"
      "systemd-journal"
    ];
    linger = true;
    authorizedKey = config.secrets.ssh-main-lab.path;
  };

  users.users.r3dlust.extraGroups = [ "kache" ];

  home-manager.sharedModules = [
    (
      { config, ... }:
      {
        home.file.".cargo/config.toml".text = lib.mkAfter ''
          target-dir = "${cargoTargetDir}/${config.home.username}"
        '';
      }
    )
  ];

  # prebuilt binaries in users' homes, such as T3's server and kittylitter,
  # run through nix-ld
  programs.nix-ld.enable = true;

  systemd.user.services.kache.serviceConfig = {
    ReadWritePaths = [ "/mnt/encrypted" ];
    UMask = "0002";
  };
}
