{ config, lib, ... }:
# macOS remaps these keys itself, for every keyboard, with no input tool or
# driver in between. nix-darwin applies the mapping again at every boot.
lib.mkIf config.isDesktop {
  system.keyboard = {
    enableKeyMapping = true;
    swapCapsLockAndEscape = true;
  };
}
