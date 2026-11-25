{
  metadata = {
    hostname = "oracle-2";
    class = "nixos";
    type = "server";
    architecture = "aarch64-linux";
    address = "100.119.88.94";
    build-architectures = [ "aarch64-linux" ];
  };

  module =
    { config, ... }:
    {
      secrets.password.file = ./password.age;
      users.users.r3dlust.authorizedKey = config.secrets.ssh-oracle-oracle-2.path;

      time.timeZone = "America/Sao_Paulo";
      system.stateVersion = "26.11";

      # opens tcp 80 and 443 and udp 443 for its virtual hosts
      services.upstreamer.enable = true;

      tailscale.exit-node = true;

      # The subnet advertises an IPv6 router but the VNIC has no IPv6 address, so a default
      # route through it only makes IPv6 connections time out.
      networking.dhcpcd.extraConfig = ''
        interface enp0s6
        ipv4only
      '';
    };
}
