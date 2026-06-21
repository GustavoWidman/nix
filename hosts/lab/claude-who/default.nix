{
  claude-who,
  config,
  pkgs,
  ...
}:
let
  kacheCacheDir = "/mnt/encrypted/oracle/kache";
  kacheExe = "${config.services.kache.package}/bin/kache";
in
{
  services.kache.settings.cache.local_store = kacheCacheDir;

  users.groups.kache = { gid = 987; };
  users.groups.oracle = { gid = 991; };

  systemd.tmpfiles.rules = [
    "d ${kacheCacheDir} 2775 ${config.services.claude-who.user} kache - -"
    "d /mnt/encrypted/oracle/cargo-target 0755 ${config.services.claude-who.user} ${config.services.claude-who.group} - -"
    "d /mnt/encrypted/oracle/cargo-target/${config.services.claude-who.user} 0755 ${config.services.claude-who.user} ${config.services.claude-who.group} - -"
    "d /mnt/encrypted/oracle/cargo-target/r3dlust 0755 r3dlust users - -"
  ];

  secrets.claude-who = {
    file = ./settings.json.age;
    mode = "400"; # read-only for owner
    owner = config.services.claude-who.user;
    group = config.services.claude-who.group;
  };

  services.claude-who = {
    enable = true;
    user = "oracle";
    group = "oracle";

    settings = config.secrets.claude-who.path;

    browser.chromiumPackage = pkgs.chromium;

    extraPackages = with pkgs; [
      "/home/${config.services.claude-who.user}/.bun"
      pkg-config
      jujutsu
      openssh
      nodejs
      codex
      config.services.kache.package
      ruby # for OMC's ralph plugin
      bun
    ];

    environment = {
      BUN_INSTALL = "/home/${config.services.claude-who.user}/.bun";
      NPM_CONFIG_PREFIX = "/home/${config.services.claude-who.user}/.npm-global";
      RUSTC_WRAPPER = kacheExe;
      CARGO_INCREMENTAL = "0";
      KACHE_CACHE_DIR = kacheCacheDir;
      CC = "${kacheExe} cc";
      CXX = "${kacheExe} c++";
    };

    extraReadWritePaths = [
      "/mnt/encrypted"
    ];
  };

  # add oracle as a home-manager user
  home-manager.users = {
    ${config.services.claude-who.user}.home = {
      stateVersion = "25.05";
      homeDirectory = "/home/${config.services.claude-who.user}";
    };
  };

  # add oracle's user to the "docker" group
  users.users.${config.services.claude-who.user} = {
    uid = 993;
    extraGroups = [
      "docker"
      "kache"
    ];
    linger = true;
  };

  users.users.r3dlust.extraGroups = [ "kache" ];

  environment.systemPackages = [
    claude-who.packages.${config.metadata.architecture}.default
  ];

  systemd.user.services.kache.serviceConfig = {
    ReadWritePaths = [ "/mnt/encrypted" ];
    UMask = "0002";
  };
}
