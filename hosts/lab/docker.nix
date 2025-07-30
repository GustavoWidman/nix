{ config, ... }:

{
  virtualisation.docker.enable = true;
  users.users.r3dlust.extraGroups = [ "docker" ];
}
