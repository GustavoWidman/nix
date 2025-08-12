{ lib, config, ... }:
let
  inherit (lib) enabled mergeIf;
in
mergeIf (config.isServer || config.isDevServer) {
  services.openssh = enabled {
    settings = {
      PasswordAuthentication = false;
    };
  };
}
