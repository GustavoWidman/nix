{ pkgs, lib, ... }:
let
  inherit (lib)
    enabled
    ;
in
{
  services.minecraft-server = enabled {
    declarative = true;
    openFirewall = true;
    eula = true;
    serverProperties = {
      difficulty = 3;
      gamemode = 0;
      spawn-protection = 0;
      max-players = 25;
      level-name = "Bedrock is Unbreakable 2 (World 2)";
    };
  };
}
