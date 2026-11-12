{
  homebrew-core,
  homebrew-cask,
  config,
  lib,
  ...
}:
let
  inherit (lib) enabled;
in
{
  homebrew = enabled;

  nix-homebrew = enabled {
    user = config.mainUser;

    taps."homebrew/homebrew-core" = homebrew-core;
    taps."homebrew/homebrew-cask" = homebrew-cask;

    mutableTaps = false;

    # most macs come with homebrew already in /opt/homebrew: take it over,
    # keeping what it installed, instead of refusing the first activation
    autoMigrate = true;
  };
}
