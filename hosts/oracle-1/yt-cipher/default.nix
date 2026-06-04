{ config, lib, ... }:
{
  services.yt-cipher = {
    enable = true;
    environment.API_TOKEN = "local-yt-cipher";
    host = "127.0.0.1";
    port = 36952;
  };

  services.lavalink.extraConfig = lib.mkIf (config.services.lavalink.enable) {
    plugins.youtube.remoteCipher = {
      url = "http://${config.services.yt-cipher.host}:${toString config.services.yt-cipher.port}";
      password = config.services.yt-cipher.environment.API_TOKEN;
    };
  };
}
