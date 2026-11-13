{
  metadata = {
    hostname = "altar";
    class = "darwin";
    type = "dev-server";
    architecture = "aarch64-darwin";
    admin = true;
    build-architectures = [ "aarch64-darwin" ];
  };

  module =
    { config, pkgs, ... }:
    {
      users.users = {
        r3dlust = {
          name = "r3dlust";
          home = "/Users/r3dlust";
          isMainUser = true;
          shell = pkgs.nushell;
          authorizedKey = config.secrets.ssh-main-altar.path;
        };

        root = {
          name = "root";
          home = "/var/root";
          shell = pkgs.nushell;
        };
      };

      home-manager.users = {
        root.home = {
          stateVersion = "25.05";
          homeDirectory = "/var/root";
        };

        r3dlust.home = {
          stateVersion = "25.05";
          homeDirectory = "/Users/r3dlust";
        };
      };

      system.stateVersion = 6;
    };
}
