{
  metadata = {
    hostname = "oracle-2";
    class = "nixos";
    type = "server";
    architecture = "aarch64-linux";
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
    };
}
