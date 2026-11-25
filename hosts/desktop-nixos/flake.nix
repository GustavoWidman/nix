{
  metadata = {
    hostname = "desktop-nixos";
    class = "nixos";
    type = "desktop";
    architecture = "x86_64-linux";
    admin = true;
    address = "100.89.162.115";
    build-architectures = [ ]; # no builds, not always on
  };

  module =
    { config, pkgs, ... }:
    {
      users.users.r3dlust.authorizedKey = config.secrets.ssh-main-desktop.path;
      secrets.password.file = ./password.age;

      time.timeZone = "America/Sao_Paulo";
      system.stateVersion = "26.11";

      networking.networkmanager.enable = true;
      environment.systemPackages = [
        pkgs.sbctl
      ];
    };
}
