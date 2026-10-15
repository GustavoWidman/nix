{ config, coeus, pkgs, ... }:
{
  secrets.coeusd-config = {
    owner = config.services.coeusd.user;
    group = config.services.coeusd.group;
    file = ./server.toml.age;
    mode = "400";
  };

  services.coeusd = {
    enable = true;
    uid = 498;

    stateDirectory = "/var/lib/coeus/state";
    configFile = config.secrets.coeusd-config.path;
    enablePasswordlessActivation = true;
  };

  environment.systemPackages = [
    coeus.packages.${pkgs.stdenv.hostPlatform.system}.coeus
  ];
}
