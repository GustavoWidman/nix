{ config, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
  };

  # re-expose hm packages to system
  environment.systemPackages = config.home-manager.users.r3dlust.home.packages;
}
