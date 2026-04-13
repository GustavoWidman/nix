{
  claude-who,
  config,
  pkgs,
  ...
}:
{
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
      bun
    ];

    environment = {
      BUN_INSTALL = "/home/${config.services.claude-who.user}/.bun";
      NPM_CONFIG_PREFIX = "/home/${config.services.claude-who.user}/.npm-global";
    };
  };

  # add oracle as a home-manager user
  home-manager.users = {
    ${config.services.claude-who.user}.home = {
      stateVersion = "25.05";
      homeDirectory = "/home/${config.services.claude-who.user}";
    };
  };

  environment.systemPackages = [
    claude-who.packages.${config.metadata.architecture}.default
  ];
}
