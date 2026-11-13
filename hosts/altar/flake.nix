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
      users.users.r3dlust = {
        home = "/Users/r3dlust";
        isMainUser = true;
        shell = pkgs.nushell;
        authorizedKey = config.secrets.ssh-main-altar.path;
      };
      home-manager.users.r3dlust = { };

      system.stateVersion = 6;
    };
}
