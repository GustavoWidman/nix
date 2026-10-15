{ config, coeus, pkgs, ... }:
{
  secrets.coeus-server-config = {
    owner = config.services.coeusd.user;
    group = config.services.coeusd.group;
    file = ./server.toml.age;
    mode = "400";
  };

  secrets.coeus-client-config = {
    owner = "r3dlust";
    file = ./client.toml.age;
    mode = "400";
  };

  services.coeusd = {
    enable = true;
    uid = 498;

    stateDirectory = "/var/lib/coeus/state";
    serverConfigFile = config.secrets.coeus-server-config.path;
    clientConfigFile = config.secrets.coeus-client-config.path;
    enablePasswordlessActivation = true;
  };

  environment.systemPackages = [
    coeus.packages.${pkgs.stdenv.hostPlatform.system}.coeus
  ];
}
