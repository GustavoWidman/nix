{ config, lib, ... }:
let
  inherit (lib)
    attrNames
    filterAttrs
    head
    last
    mkConst
    mkEnum
    hasPrefix
    splitString
    ;
in
{
  options = {
    os = mkConst <| last <| splitString "-" config.nixpkgs.hostPlatform.system;
    arch = mkConst config.nixpkgs.hostPlatform.system;
    type = mkEnum "server" [
      "desktop"
      "server"
      "dev-server"
    ];

    isLinux = mkConst <| config.os == "linux";
    isDarwin = mkConst <| config.os == "darwin";

    isDesktop = mkConst <| config.type == "desktop";
    isServer = mkConst <| config.type == "server";
    isDevServer = mkConst <| config.type == "dev-server";
    isDev = mkConst <| (config.type == "dev-server" || config.type == "desktop");

    isLinuxServer = mkConst <| (config.os == "linux" && config.type == "server");
    isLinuxDesktop = mkConst <| (config.os == "linux" && config.type == "desktop");
    isLinuxDevServer = mkConst <| (config.os == "linux" && config.type == "dev-server");
    isLinuxDev =
      mkConst <| (config.os == "linux" && (config.type == "dev-server" || config.type == "desktop"));

    isDarwinServer = mkConst <| (config.os == "darwin" && config.type == "server");
    isDarwinDesktop = mkConst <| (config.os == "darwin" && config.type == "desktop");
    isDarwinDevServer = mkConst <| (config.os == "darwin" && config.type == "dev-server");
    isDarwinDev =
      mkConst <| (config.os == "darwin" && (config.type == "dev-server" || config.type == "desktop"));

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
