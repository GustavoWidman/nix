{
  config,
  lib,
  ...
}:
let
  inherit (lib) mapAttrsToList;

  hmUsers =
    config.home-manager.users
    |> mapAttrsToList (userName: userConfig: {
      name = userName;
      home = userConfig.home.homeDirectory;
    });
in
{
  # agenix creates .ssh/ as root when deploying secrets into home directories.
  # tmpfiles runs after agenix but before home-manager user services, fixing
  # ownership so HM can write its own symlinks (e.g. ~/.ssh/config).
  systemd.tmpfiles.rules = map (user: "d ${user.home}/.ssh 0700 ${user.name} ${user.name} -") hmUsers;
}
