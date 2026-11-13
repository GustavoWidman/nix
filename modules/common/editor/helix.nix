{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    attrValues
    elem
    enabled
    mapAttrs
    mkIf
    optionalAttrs
    ;

  formattedLanguages =
    {
      astro = "astro";
      css = "css";
      html = "html";
      javascript = "js";
      json = "json";
      jsonc = "jsonc";
      jsx = "jsx";
      markdown = "md";
      scss = "scss";
      svelte = "svelte";
      tsx = "tsx";
      typescript = "ts";
      vue = "vue";
      yaml = "yaml";
    }
    |> mapAttrs (
      name: extension:
      {
        inherit name;

        auto-format = true;
        formatter.command = "deno";
        formatter.args = [
          "fmt"
          "--unstable-component"
          "--ext"
          extension
          "-"
        ];
        file-types = [
          extension
          { glob = "*.${extension}.*"; }
        ];
      }
      //
        optionalAttrs
          (elem name [
            "javascript"
            "jsx"
            "typescript"
            "tsx"
          ])
          {
            language-servers = mkIf config.isDev [ "deno" ];
          }
    )
    |> attrValues;

  languages = formattedLanguages ++ [
    {
      name = "nix";
      auto-format = true;
      formatter.command = "nixfmt";
      file-types = [
        "nix"
        { glob = "*.nix.*"; }
      ];
    }

    {
      name = "python";
      auto-format = true;
      language-servers = mkIf config.isDev [ "basedpyright" ];
      file-types = [
        "py"
        { glob = "*.py.*"; }
      ];
    }

    {
      name = "toml";
      auto-format = true;
      file-types = [
        "toml"
        { glob = "*.toml.*"; }
      ];
    }

    {
      name = "rust";
      auto-format = true;
      language-servers = mkIf config.isDev [ "rust-analyzer" ];
      file-types = [
        "rs"
        { glob = "*.rs.*"; }
      ];
    }
    {
      name = "sshclientconfig";
      file-types = [
        "ssh"
        "~/.ssh/config"
        { glob = "~/.ssh/**/config"; }
        { glob = "*.ssh.*"; }
      ];
    }
    {
      name = "env";
      file-types = [
        "env"
        { glob = "*.env.*"; }
        { glob = "*.env"; }
      ];
    }
    {
      name = "caddyfile";
      auto-format = true;
    }
    {
      name = "bash";
      auto-format = true;
      file-types = [
        "sh"
        "bash"
        { glob = "*.sh.*"; }
        { glob = "*.bash.*"; }
      ];
    }
    {
      name = "go";
      auto-format = true;
      file-types = [
        "go"
        { glob = "*.go.*"; }
      ];
      formatter.command = "gofmt";
    }
  ];

  languageServers = {
    deno = {
      command = "deno";
      args = [ "lsp" ];

      environment.NO_COLOR = "1";

      config.javascript = enabled {
        lint = true;
        unstable = true;

        suggest.imports.hosts."https://deno.land" = true;

        inlayHints.enumMemberValues.enabled = true;
        inlayHints.functionLikeReturnTypes.enabled = true;
        inlayHints.parameterNames.enabled = "all";
        inlayHints.parameterTypes.enabled = true;
        inlayHints.propertyDeclarationTypes.enabled = true;
        inlayHints.variableTypes.enabled = true;
      };
    };

    rust-analyzer = {
      config = {
        cargo.features = "all";
        check.command = "clippy";
      };
    };
  };
in
{
  environment.variables = {
    EDITOR = "hx";
  };

  home-manager.sharedModules = [
    {
      programs.helix = enabled {
        languages.language = languages;
        languages.language-server = languageServers;

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

        settings.editor.soft-wrap.enable = true;

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
