{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    enabled
    ;
in
{
  editor.defaultAlias = "hx";

  home-manager.sharedModules = [
    {
      programs.helix = enabled {
        languages.language = config.editor.languageConfigsHelix;
        languages.language-server = config.editor.lspConfigsHelix;

        settings.theme = "gruvbox";

        settings.editor = {
          auto-completion = true;
          bufferline = "multiple";
          color-modes = true;
          cursorline = true;
          file-picker.hidden = false;
          idle-timeout = 0;
          shell = [
            "nu"
            "--commands"
          ];
          text-width = 100;
        };

        settings.editor.cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        settings.editor.statusline.mode = {
          insert = "INSERT";
          normal = "NORMAL";
          select = "SELECT";
        };

        settings.editor.indent-guides = {
          character = "▏";
          render = true;
        };

        settings.editor.whitespace = {
          characters.tab = "→";
          render.tab = "all";
        };

        settings.keys = {
          normal = {
            "Cmd-s" = [
              ":format"
              ":write"
            ];
          };
          select = {
            "Cmd-s" = [
              ":format"
              ":write"
            ];
          };
          insert = {
            "Cmd-s" = [
              "normal_mode"
              ":format"
              ":write"
            ];
          };
        };
      };
    }
  ];
}
