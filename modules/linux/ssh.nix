{
  config,
  lib,
  ...
}:
let
  inherit (lib) mapAttrsToList;
in
{
  # agenix creates .ssh/ as root when deploying secrets into home directories.
  # tmpfiles runs after agenix but before home-manager user services, fixing
  # ownership so HM can write its own symlinks (e.g. ~/.ssh/config).
  systemd.tmpfiles.rules =
    config.home-manager.users
    |> mapAttrsToList (name: user: "d ${user.home.homeDirectory}/.ssh 0700 ${name} ${name} -");
}
