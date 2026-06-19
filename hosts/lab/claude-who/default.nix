{
  claude-who,
  config,
  pkgs,
  ...
}:
let
  kacheCacheDir = "/mnt/encrypted/oracle/kache";
in
{
  services.kache.settings.cache.local_store = kacheCacheDir;

  users.groups.kache = { };

  systemd.tmpfiles.rules = [
    "d ${kacheCacheDir} 0775 ${config.services.claude-who.user} kache - -"
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
      sccache
      ruby # for OMC's ralph plugin
      bun
    ];

    environment = {
      BUN_INSTALL = "/home/${config.services.claude-who.user}/.bun";
      NPM_CONFIG_PREFIX = "/home/${config.services.claude-who.user}/.npm-global";
      RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
      CARGO_INCREMENTAL = "0";
      SCCACHE_CACHE_SIZE = "20G";
      SCCACHE_DIR = "/home/${config.services.claude-who.user}/.cache/sccache";
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
}
