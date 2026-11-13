{
  homebrew-core,
  homebrew-cask,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    attrValues
    concatMapStrings
    enabled
    mkBefore
    ;
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

  # the taps are pinned, so nix-homebrew links Library/Taps to the store and
  # refuses a mac whose own Taps directory is in the way: that one is kept
  # aside instead. a Taps already linked to the store is left alone.
  system.activationScripts.preActivation.text = mkBefore (
    concatMapStrings (prefix: ''
      taps=${prefix.library}/Taps
      if [ -d "$taps" ] && [ ! -L "$taps" ]; then
        echo "keeping the existing $taps aside as $taps.before-nix-darwin"
        mv "$taps" "$taps.before-nix-darwin.$(date +%s)"
      fi
    '') (attrValues config.nix-homebrew.prefixes)
  );
}
