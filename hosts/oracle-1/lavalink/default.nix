{ config, ... }:
{
  secrets.lavalink-environment = {
    file = ./environment.env.age;
    owner = "lavalink";
    group = "lavalink";
    mode = "0400";
  };

  services.lavalink = {
    enable = true;
    address = "127.0.0.1";
    port = 47164;
    environmentFile = config.secrets.lavalink-environment.path;
    enableHttp2 = true;

    extraConfig.lavalink.server.sources.youtube = false;

    plugins = [
      {
        dependency = "dev.lavalink.youtube:youtube-plugin:1.18.1";
        repository = "https://maven.lavalink.dev/releases";
        hash = "sha256-DGJgXQ4B3JVApn++25umsGnEQjcxe02YwWupkl4L4Yg=";
        configName = "youtube";
        extraConfig = {
          enabled = true;
          allowSearch = true;
          allowDirectVideoIds = true;
          allowDirectPlaylistIds = true;
          oauth = {
            enabled = true;
            skipInitialization = true;
          };
          clients = [
            "TV"
            "WEB"
            "MWEB"
            "WEBEMBEDDED"
            "ANDROID_MUSIC"
            "ANDROID_VR"
            "TVHTML5_SIMPLY"
          ];
        };
      }

      {
        dependency = "com.github.topi314.lavasrc:lavasrc-plugin:4.8.3";
        repository = "https://maven.lavalink.dev/releases";
        hash = "sha256-TsOJva5k/Tge5i/NuQLhXZQCgjsa0LmCvVYzYZoHwbM=";
        configName = "lavasrc";
        extraConfig = {
          providers = [
            "ytsearch:\"%ISRC%\""
            "ytmsearch:%QUERY%"
            "scsearch:%QUERY%"
          ];

          sources = {
            spotify = false;
            applemusic = false;
            deezer = false; # todo
            yandexmusic = false; # todo
            tidal = false; # todo
            qobuz = false;
            flowerytts = false;
            youtube = false; # youtube plugin owns youtube
          };

          spotify = {
            # fill from env/config later if we want Spotify metadata
            clientId = "";
            clientSecret = "";
            countryCode = "BR";
            playlistLoadLimit = 6;
            albumLoadLimit = 6;
          };

          applemusic = {
            countryCode = "BR";
            mediaAPIToken = "";
            playlistLoadLimit = 6;
            albumLoadLimit = 6;
          };

          deezer = {
            masterDecryptionKey = "";
            arl = "";
          };
        };
      }

      {
        dependency = "com.github.topi314.lavasearch:lavasearch-plugin:1.0.0";
        repository = "https://maven.lavalink.dev/releases";
        hash = "sha256-nDDa1NuXzp8AOhTt0Jos1YtiiSShDWN21Qpo7pO5O1M=";
        configName = "lavasearch";
        extraConfig = {
          enabled = true;
        };
      }

      {
        dependency = "com.github.topi314.sponsorblock:sponsorblock-plugin:3.0.1";
        repository = "https://maven.lavalink.dev/releases";
        hash = "sha256-kVDukbe6AJalLuKfBB8lvF0l91d7p4/IB0oQxlfWjbQ=";
        configName = "sponsorblock";
        extraConfig = {
          enabled = true;
        };
      }

      {
        dependency = "com.github.topi314.lavalyrics:lavalyrics-plugin:1.1.0";
        repository = "https://maven.lavalink.dev/releases";
        hash = "sha256-tp20AKkmaFkS/3jp/0Avo0P92fZhsWMh9J8aywhzwog=";
        configName = "lavalyrics";
        extraConfig = {
          enabled = true;
        };
      }
    ];
  };
}
