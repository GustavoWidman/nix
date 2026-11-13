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

      networking.firewall = {
        allowedTCPPorts = [
          80
          443
        ];
        allowedUDPPorts = [ 443 ];
      };

      tailscale.exit-node = true;
    };
}
