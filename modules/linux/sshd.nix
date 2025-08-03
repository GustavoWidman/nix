{ lib, ... }:
let
  inherit (lib) enabled;
in
{
  services.openssh = enabled {
    settings = {
      PasswordAuthentication = false;
    };
  };
}
