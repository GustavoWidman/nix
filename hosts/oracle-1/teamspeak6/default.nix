{ lib, pkgs, ... }:
let
  dataDir = "/var/lib/teamspeak6";
  voicePort = 9987;
  fileTransferPort = 30033;

  # Publish TeamSpeak only through the secondary OCI address.
  bindAddress = "10.0.0.200";
in
{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers.teamspeak6 = {
    # oracle-1 is aarch64; pin the matching arm64 manifest digest.
    image = "docker.io/teamspeaksystems/teamspeak6-server:6.0.0-beta13.1@sha256:a89b53db7b4a213251a47b652b212d1314728ec8c498f5246cf7e7622587ed89";
    autoStart = true;
    ports = [
      "${bindAddress}:${toString voicePort}:${toString voicePort}/udp"
      "${bindAddress}:${toString fileTransferPort}:${toString fileTransferPort}/tcp"
    ];
    volumes = [ "${dataDir}:/var/tsserver" ];
    environment = {
      TSSERVER_LICENSE_ACCEPTED = "accept";
      TSSERVER_DEFAULT_PORT = toString voicePort;
      TSSERVER_FILE_TRANSFER_PORT = toString fileTransferPort;
    };
  };

  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 9987 9987 -" ];
  systemd.services.podman-teamspeak6.preStart = lib.mkAfter ''
    ${pkgs.coreutils}/bin/chown -R 9987:9987 ${dataDir}
  '';

  networking.firewall.allowedUDPPorts = [ voicePort ];
  networking.firewall.allowedTCPPorts = [ fileTransferPort ];
}
