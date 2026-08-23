{ ... }:

{
  services.teamspeak6 = {
    enable = true;

    # oracle-1 is aarch64; pin the matching arm64 manifest digest.
    image = "docker.io/teamspeaksystems/teamspeak6-server:latest@sha256:2a92e24bcc05a0e1b211a83735f6e2cbe80e33a31414a6f1811602005a6b92dd";

    # Publish TeamSpeak only through the secondary OCI address.
    bindAddress = "10.0.0.200";

    # Voice and file transfer use the standard public ports.
    voicePort = 9987;
    fileTransferPort = 30033;
    enableQuery = false;
  };
}
