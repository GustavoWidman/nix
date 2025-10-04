{ config, lib, ... }:
let
  inherit (lib)
    enabled
    ;
in
{
  secrets.xray-config = {
    file = ./config.json.age;
    owner = "xray";
    group = "xray";
  };

  services.xray = enabled {
    settingsFile = config.secrets."xray-config".path;
  };

  users.users.xray = {
    name = "xray";
    group = "xray";
    isSystemUser = true;
  };
  users.groups.xray = {
    name = "xray";
  };
  systemd.services.xray = {
    serviceConfig = {
      User = "xray";
      Group = "xray";
      DynamicUser = lib.mkForce false;
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 443 ];
    allowedUDPPorts = [ 443 ];
  };
}
