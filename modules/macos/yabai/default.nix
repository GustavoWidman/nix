{ lib, pkgs, ... }:
let
  inherit (lib)
    enabled
    ;
in
{
  homebrew.casks = [ "spaceid" ];

  services.yabai = enabled {
    enableScriptingAddition = true;
    config = {
      focus_follows_mouse = "off";
      mouse_follows_focus = "off";
      window_placement = "second_child";
      window_opacity = "off";
      top_padding = 4;
      bottom_padding = 4;
      left_padding = 4;
      right_padding = 4;
      window_gap = 8;
      layout = "bsp";
      window_shadow = "float";
    };
    extraConfig = ''
      ${pkgs.nushell}/bin/nu ${./init.nu}
    '';
  };
}
