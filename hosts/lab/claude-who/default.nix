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

    extraPackages = with pkgs; [
      jujutsu
      openssh
      bun
    ];
  };

  # add oracle as a home-manager user
  home-manager.users = {
    ${config.services.claude-who.user}.home = {
      stateVersion = "25.05";
      homeDirectory = "/home/${config.services.claude-who.user}";
    };
  };

  environment.systemPackages = with pkgs; [
    claude-who.packages.${config.metadata.architecture}.default
    chromium # make chromium available system-wide for the playwright MCP
  ];
}
