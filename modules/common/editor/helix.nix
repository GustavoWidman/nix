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
  environment.variables = {
    EDITOR = "hx";
  };

  home-manager.sharedModules = [
    {
      programs.helix = enabled {
        languages.language = config.editor.languageConfigsHelix;
        languages.language-server = config.editor.lspConfigsHelix;

        settings.theme = "gruvbox";

        settings.editor = {
          auto-completion = true;
          bufferline = "always";
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
            "Cmd-x" = [
              "extend_to_line_bounds"
              "delete_selection"
            ];
            "Cmd-z" = "undo";
            "Cmd-Z" = "redo";
          };
          select = {
            "Cmd-s" = [
              ":format"
              ":write"
            ];
            "Cmd-x" = [
              "extend_to_line_bounds"
              "delete_selection"
            ];
            "Cmd-z" = "undo";
            "Cmd-Z" = "redo";
          };
          insert = {
            "Cmd-s" = [
              "normal_mode"
              ":format"
              ":write"
            ];
            "Cmd-x" = [
              "extend_to_line_bounds"
              "delete_selection"
            ];
            "Cmd-z" = "undo";
            "Cmd-Z" = "redo";
          };
        };
      };
    }
  ];
}
