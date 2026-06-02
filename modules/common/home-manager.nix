{ config, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";

    sharedModules = [
      {
        manual.json.enable = false;
        manual.manpages.enable = false;
      }
    ];
  };

  # re-expose hm packages to system
  environment.systemPackages = config.home-manager.users.r3dlust.home.packages;
}
