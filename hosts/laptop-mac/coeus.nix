{ coeus, pkgs, ... }:
{
  services.coeusd = {
    enable = true;
    uid = 498;

    # Reuse your Git/SSH setup, without root builds.
    # createUser = false;
    # user = "r3dlust";
    # group = "staff";
    # home = "/Users/r3dlust";

    stateDirectory = "/var/lib/coeus/state";
    configFile = "/Users/r3dlust/.config/coeus/server.toml";
    enablePasswordlessActivation = true;
  };

  environment.systemPackages = [
    coeus.packages.${pkgs.stdenv.hostPlatform.system}.coeus
  ];
}
