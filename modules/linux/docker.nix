{ config, ... }:

{
  virtualisation.docker.enable = true;
  users.users.${config.mainUser}.extraGroups = [ "docker" ];
}
