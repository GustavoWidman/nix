{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) attrValues;
in
{
  environment.systemPackages = attrValues {
    inherit (pkgs)
      exfat # fails to build on darwin
      inotify-tools
      usbutils
      xfsprogs
      wol
      ;
  };
}
