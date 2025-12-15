{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    enabled
    ;

  eulaFile = builtins.toFile "eula.txt" ''
    # eula.txt managed by NixOS Configuration
    eula=true
  '';

  cfgToString = v: if builtins.isBool v then lib.boolToString v else toString v;

  serverPropertiesFile = pkgs.writeText "server.properties" (
    ''
      # server.properties managed by NixOS configuration
    ''
    + lib.concatStringsSep "\n" (
      lib.mapAttrsToList (n: v: "${n}=${cfgToString v}") config.services.minecraft-server.serverProperties
    )
  );
in
{
  secrets.minecraft-server-whitelist = {
    file = ./whitelist.json.age;
    owner = "minecraft";
    group = "minecraft";
    path = config.services.minecraft-server.dataDir + "/whitelist.json";
    mode = "0644";
  };

  services.minecraft-server = enabled {
    openFirewall = false;
    eula = true;
    serverProperties = {
      difficulty = 3;
      gamemode = 0;
      spawn-protection = 0;
      max-players = 25;
      # level-name = "Bedrock is Unbreakable 2 (World 2)";
      white-list = true;
      enforce-whitelist = true;
    };
  };

  networking.firewall = {
    allowedUDPPorts = [ 25565 ];
    allowedTCPPorts = [ 25565 ];
  };

  systemd.services.minecraft-server.preStart = lib.mkForce ''
    ln -sf ${eulaFile} eula.txt
    cp -f ${serverPropertiesFile} server.properties
  '';
}
