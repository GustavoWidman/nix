{ lib, ... }:
let
  inherit (lib) enabled;
  port = 2222;
in
{
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
}
