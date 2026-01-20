{ lib, config, ... }:
let
  inherit (lib)
    mergeIf
    ;
in
mergeIf (config.isLinux) {
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    # systemd.enable = true;
  };
}
