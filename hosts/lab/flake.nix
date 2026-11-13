{
  metadata = {
    hostname = "lab";
    class = "nixos";
    type = "dev-server";
    architecture = "x86_64-linux";
    admin = true;
    build-architectures = [ "x86_64-linux" ];
  };

  module =
    { config, ... }:
    {
      secrets.password.file = ./password.age;
      users.users.r3dlust.authorizedKey = config.secrets.ssh-main-lab.path;

      time.timeZone = "America/Sao_Paulo";
      system.stateVersion = "25.05";

      # lab builds only for its own architecture; unset, nix would add
      # i686-linux and the x86_64 microarchitecture levels
      nix.settings.extra-platforms = [ ];

      services.netbird.enable = true;

      tailscale = {
        exit-node = true;
        advertise-routes = [
          "192.168.101.0/24"
        ];
      };
    };
}
