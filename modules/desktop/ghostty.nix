{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    enabled
    mkIf
    ;
in
{
  environment.variables = {
    TERMINAL = mkIf config.isLinux "ghostty";
    TERM_PROGRAM = mkIf config.isDarwin "ghostty";
  };

  home-manager.sharedModules = [
    {
      programs.ghostty = enabled {
        package = mkIf config.isDarwin pkgs.ghostty-bin;

        settings = {
          theme = "Gruvbox Dark";

          font-family = "JetBrains Mono";
          font-codepoint-map = "U+E0A0=Fira Code";
          font-size = 18;

          window-colorspace = mkIf config.isDarwin "display-p3";
          window-height = 42;
          window-width = 150;

          mouse-hide-while-typing = true;

          auto-update = "off";

          cursor-click-to-move = true;
          cursor-style = "bar";

          macos-titlebar-proxy-icon = mkIf config.isDarwin "hidden";
          macos-titlebar-style = mkIf config.isDarwin "tabs";
          macos-secure-input-indication = mkIf config.isDarwin false;

          shell-integration = "none";
          shell-integration-features = [
            "sudo"
            "no-cursor"
          ];

          keybind = [ "super+e=new_tab" ];
        };
      };
    }
  ];
}
