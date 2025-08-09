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
          theme = "GruvboxDark";
          # theme = "Dracula";

          font-family = "Fira Code Regular";
          # font-family = "JetBrains Mono";
          font-size = 18;

          window-colorspace = mkIf config.isDarwin "display-p3";
          window-height = 42;
          window-width = 150;

          # background-opacity = 0.85;
          # background-opacity = 0.9;

          mouse-hide-while-typing = true;

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
