{
  lib,
  ...
}:
let
  inherit (lib) mkAliasOptionModule;
in
{
  imports = [ (mkAliasOptionModule [ "secrets" ] [ "age" "secrets" ]) ];

  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
  ];
}
