{ config, lib, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";

    sharedModules = [
      {
        home.stateVersion = lib.mkDefault "26.11";

        manual.json.enable = false;
        manual.manpages.enable = false;
      }
    ];
  };

  # re-expose hm packages to system
  environment.systemPackages = config.home-manager.users.${config.mainUser}.home.packages;
}
