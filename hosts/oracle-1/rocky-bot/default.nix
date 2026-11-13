{ config, rocky-bot, ... }:

{
  imports = [ rocky-bot.nixosModules.default ];

  secrets.rocky-bot-config.file = ./rocky-bot.toml.age;

  services.rocky-bot = {
    enable = true;
    config = config.secrets.rocky-bot-config.path;
  };
}
