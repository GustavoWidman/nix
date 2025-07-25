{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkAliasOptionModule
    mkIf
    ;
in
{
  imports = [ (mkAliasOptionModule [ "secrets" ] [ "age" "secrets" ]) ];

  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
  ];

  environment = mkIf config.isDesktop {
    systemPackages = with pkgs; [
      agenix
    ];
  };
}
