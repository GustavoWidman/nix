{ config, lib, ... }:
{
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = lib.mkIf config.isDesktop true;
}
