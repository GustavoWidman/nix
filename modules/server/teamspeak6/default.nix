{ config, lib, pkgs, ... }:

let
  cfg = config.services.teamspeak6;
in
{
  options.services.teamspeak6 = {
    enable = lib.mkEnableOption "the TeamSpeak 6 server";
    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/teamspeaksystems/teamspeak6-server:latest";
      description = "TeamSpeak 6 container image; pin to a digest for production.";
    };
    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/teamspeak6";
      description = "Persistent TeamSpeak data directory.";
    };
    voicePort = lib.mkOption { type = lib.types.port; default = 9987; };
    fileTransferPort = lib.mkOption { type = lib.types.port; default = 30033; };
    queryPort = lib.mkOption { type = lib.types.port; default = 10080; };
    enableQuery = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose the HTTP ServerQuery interface.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.podman.enable = true;
    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers.teamspeak6 = {
      inherit (cfg) image;
      autoStart = true;
      ports = [
        "${toString cfg.voicePort}:${toString cfg.voicePort}/udp"
        "${toString cfg.fileTransferPort}:${toString cfg.fileTransferPort}/tcp"
      ] ++ lib.optional cfg.enableQuery
        "127.0.0.1:${toString cfg.queryPort}:${toString cfg.queryPort}/tcp";
      volumes = [ "${cfg.dataDir}:/var/tsserver" ];
      environment = {
        TSSERVER_LICENSE_ACCEPTED = "accept";
        TSSERVER_DEFAULT_PORT = toString cfg.voicePort;
        TSSERVER_FILE_TRANSFER_PORT = toString cfg.fileTransferPort;
      } // lib.optionalAttrs cfg.enableQuery {
        TSSERVER_QUERY_HTTP_ENABLED = "1";
        TSSERVER_QUERY_HTTP_PORT = toString cfg.queryPort;
      };
    };
    systemd.tmpfiles.rules = [ "d ${cfg.dataDir} 0750 9987 9987 -" ];
    systemd.services.podman-teamspeak6.preStart = lib.mkAfter ''
      ${pkgs.coreutils}/bin/chown -R 9987:9987 ${cfg.dataDir}
    '';
    networking.firewall.allowedUDPPorts = [ cfg.voicePort ];
    networking.firewall.allowedTCPPorts = [ cfg.fileTransferPort ]
      ++ lib.optional cfg.enableQuery cfg.queryPort;
  };
}
