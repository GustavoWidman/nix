{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    attrNames
    filterAttrs
    head
    mkConst
    mkOption
    hasPrefix
    types
    ;
in
{
  options = {
    metadata = mkOption {
      type = types.submodule {
        options.hostname = mkOption {
          type = types.str;
        };
        options.class = mkOption {
          type = lib.types.enum [
            "nixos"
            "darwin"
          ];
        };
        options.type = mkOption {
          type = lib.types.enum [
            "desktop"
            "server"
            "dev-server"
          ];
        };
        options.architecture = mkOption {
          type = lib.types.enum [
            "aarch64-linux"
            "x86_64-linux"
            "aarch64-darwin"
            "x86_64-darwin"
          ];
          default = pkgs.stdenv.hostPlatform.system;
        };
        options.build-architectures = mkOption {
          type = lib.types.listOf (
            lib.types.enum [
              "aarch64-linux"
              "x86_64-linux"
              "aarch64-darwin"
              "x86_64-darwin"
            ]
          );
          default = [ pkgs.stdenv.hostPlatform.system ];
        };
        # an admin's host key opens every secret, so it can rekey them and
        # bootstrap new machines; keys.nix reads it as the `admins` group
        options.admin = mkOption {
          type = types.bool;
          default = false;
        };
      };
    };

    isLinux = mkConst <| config.metadata.class == "nixos";
    isDarwin = mkConst <| config.metadata.class == "darwin";

    isDesktop = mkConst <| config.metadata.type == "desktop";
    isDevServer = mkConst <| config.metadata.type == "dev-server";
    isDev = mkConst <| (config.metadata.type == "dev-server" || config.metadata.type == "desktop");

    mainUser =
      mkConst
      <| head
      <| attrNames
      <| filterAttrs (
        _: value:
        value.home != null
        && hasPrefix (if config.isDarwin then "/Users/" else "/home/") value.home
        && value.isMainUser
      ) config.users.users;
  };
}
