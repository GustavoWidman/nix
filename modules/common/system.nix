{ config, lib, ... }:
let
  inherit (lib)
    attrNames
    filterAttrs
    head
    last
    mkConst
    mkValue
    hasPrefix
    splitString
    ;
in
{
  options = {
    os = mkConst <| last <| splitString "-" config.nixpkgs.hostPlatform.system;

    isLinux = mkConst <| config.os == "linux";
    isDarwin = mkConst <| config.os == "darwin";

    type = mkValue "server";

    isDesktop = mkConst <| config.type == "desktop";
    isServer = mkConst <| config.type == "server";

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
