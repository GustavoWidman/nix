{ config, lib, ... }:
{
  # root's coeusd and the main user's CLI both read it
  secrets.coeus-key = {
    file = ./key.age;
    owner = config.mainUser;
    mode = "400";
  };

  services.coeus = {
    enable = true;
    keyFile = config.secrets.coeus-key.path;
    flake = "git+https://github.com/GustavoWidman/nix";
    follow = {
      ref = "deployed";
      interval = "15m";
    };
    hosts = lib.coeusHosts;
  };
}
