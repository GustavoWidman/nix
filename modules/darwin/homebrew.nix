{
  homebrew-core,
  homebrew-cask,
  swipe-aero-space,
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
    taps."mediosz/homebrew-tap" = swipe-aero-space;

    mutableTaps = false;
  };
}
