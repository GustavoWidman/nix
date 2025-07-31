{ lib, config, ... }:

let
  inherit (lib)
    enabled
    ;
in
{
  secrets.dailybot-config = {
    file = ./config.toml.age;
    owner = config.services.dailybot-free.user;
  };
  secrets.dailybot-creds = {
    file = ./creds.json.age;
    owner = config.services.dailybot-free.user;
  };

  services.dailybot-free = enabled {
    configFile = config.secrets.dailybot-config.path;
    googleCredentialsFile = config.secrets.dailybot-creds.path;
  };
}
