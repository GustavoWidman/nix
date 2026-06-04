{ config, lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optional
    types
    ;

  cfg = config.services.yt-cipher;
in
{
  options.services.yt-cipher = {
    enable = mkEnableOption "yt-cipher remote cipher service";

    package = mkOption {
      type = types.str;
      default = "ghcr.io/kikkia/yt-cipher:master";
      description = "OCI image to run for yt-cipher.";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host address to bind the yt-cipher port on.";
    };

    port = mkOption {
      type = types.port;
      default = 8001;
      description = "Host port to expose for yt-cipher.";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Extra environment variables passed to the yt-cipher container.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Environment file passed to the yt-cipher container, usually an agenix secret with API_TOKEN.";
    };

    extraOptions = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra OCI runtime options for the yt-cipher container.";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.yt-cipher = {
      image = cfg.package;
      environment = {
        HOST = "0.0.0.0";
        PORT = toString cfg.port;
      }
      // cfg.environment;
      environmentFiles = optional (cfg.environmentFile != null) cfg.environmentFile;
      ports = [ "${cfg.host}:${toString cfg.port}:${toString cfg.port}" ];
      extraOptions = [ "--pull=always" ] ++ cfg.extraOptions;
    };
  };
}
