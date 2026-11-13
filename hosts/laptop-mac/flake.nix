{
  metadata = {
    hostname = "laptop-mac";
    class = "darwin";
    type = "desktop";
    architecture = "aarch64-darwin";
    admin = true;
    build-architectures = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
  };

  module =
    { config, pkgs, ... }:
    {
      users.users.r3dlust = {
        home = "/Users/r3dlust";
        isMainUser = true;
        shell = pkgs.nushell;
        authorizedKey = config.secrets.ssh-main-laptop.path;
      };
      home-manager.users.r3dlust = { };

      system.stateVersion = 5;

      environment.systemPackages = [ pkgs.libheif ];
    };
}
