{ config, ... }:
{
  secrets.thoth-config = {
    file = ./config.toml.age;
    owner = config.services.thoth.user;
    group = config.services.thoth.group;
    mode = "400";
  };

  services.thoth = {
    enable = true;

    user = "oracle";
    group = "oracle";
    createUser = false;

    home = "/home/oracle/.thoth";
    workspace = "/home/oracle";
    statePath = "/home/oracle/.thoth/state";
    cachePath = "/home/oracle/.cache/thoth";
    agentDir = "/home/oracle/.thoth/agent";

    configFile = config.secrets.thoth-config.path;

    environment = {
      GH_CONFIG_DIR = "/home/oracle/.config/gh";
      RLM_MAX_DEPTH = "5";
    };
  };
}
