{ ... }:

{
  services.teamspeak6 = {
    enable = true;

    # oracle-1 is aarch64; pin the matching arm64 manifest digest.
    image = "docker.io/teamspeaksystems/teamspeak6-server:6.0.0-beta13.1@sha256:a89b53db7b4a213251a47b652b212d1314728ec8c498f5246cf7e7622587ed89";

    # Publish TeamSpeak only through the secondary OCI address.
    bindAddress = "10.0.0.200";

    # Voice and file transfer use the standard public ports.
    voicePort = 9987;
    fileTransferPort = 30033;
    enableQuery = false;
  };
}
