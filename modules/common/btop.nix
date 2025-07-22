{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) enabled;
in
{
  home-manager.sharedModules = [
    {
      xdg.configFile."btop/themes/gruvbox.theme".source = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/aristocratos/btop/refs/heads/main/themes/gruvbox_dark_v2.theme";
        hash = "sha256-/aek8yhMB4aeSGnAmZbHH9Pt5dnLUH/P0a/c/VPoG2Y=";
      };

      programs.btop = enabled {
        settings.color_theme = "gruvbox";
      };
    }
  ];
}
