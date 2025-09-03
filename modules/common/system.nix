{ config, lib, ... }:
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
          default = config.nixpkgs.hostPlatform.system;
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
          default = [ config.nixpkgs.hostPlatform.system ];
        };
      };
    };

    isLinux = mkConst <| config.metadata.class == "nixos";
    isDarwin = mkConst <| config.metadata.class == "darwin";

    isDesktop = mkConst <| config.metadata.type == "desktop";
    isServer = mkConst <| config.metadata.type == "server";
    isDevServer = mkConst <| config.metadata.type == "dev-server";
    isDev = mkConst <| (config.metadata.type == "dev-server" || config.metadata.type == "desktop");

    isLinuxServer = mkConst <| (config.metadata.class == "nixos" && config.metadata.type == "server");
    isLinuxDesktop = mkConst <| (config.metadata.class == "nixos" && config.metadata.type == "desktop");
    isLinuxDevServer =
      mkConst <| (config.metadata.class == "nixos" && config.metadata.type == "dev-server");
    isLinuxDev =
      mkConst
      <| (
        config.metadata.class == "nixos"
        && (config.metadata.type == "dev-server" || config.metadata.type == "desktop")
      );

    isDarwinServer = mkConst <| (config.metadata.class == "darwin" && config.metadata.type == "server");
    isDarwinDesktop =
      mkConst <| (config.metadata.class == "darwin" && config.metadata.type == "desktop");
    isDarwinDevServer =
      mkConst <| (config.metadata.class == "darwin" && config.metadata.type == "dev-server");
    isDarwinDev =
      mkConst
      <| (
        config.metadata.class == "darwin"
        && (config.metadata.type == "dev-server" || config.metadata.type == "desktop")
      );

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
    homeDir = mkConst <| "${if config.isLinux then "/home" else "/Users"}/${config.mainUser}";
  };
}
