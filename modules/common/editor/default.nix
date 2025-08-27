{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    attrValues
    enabled
    mkIf
    mkValue
    mapAttrs
    optionalAttrs
    elem
    ;
in
{
  options.editor.languageConfigsHelix = mkValue (
    let
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
                language-servers = [ "deno" ];
              }
        )
        |> attrValues;
    in
    formattedLanguages
    ++ [
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
        language-servers = [ "basedpyright" ];
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
        language-servers = [ "rust-analyzer" ];
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
    ]
  );

  options.editor.lspConfigsHelix = mkValue {
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

  config.environment = {
    systemPackages = mkIf config.isDesktop [
      # BASH
      pkgs.bash-language-server

      # CADDY
      pkgs.caddy

      # CMAKE
      # pkgs.cmake-language-server  #! TODO re-enable, build is broken

      # GO
      pkgs.gopls

      # HTML
      pkgs.vscode-langservers-extracted

      # KOTLIN
      pkgs.kotlin-language-server

      # LATEX
      pkgs.texlab

      # LUA
      pkgs.lua-language-server

      # MARKDOWN
      pkgs.markdown-oxide

      # NIX
      pkgs.nixfmt-rfc-style
      pkgs.nixd

      # PYTHON
      pkgs.basedpyright

      # RUST
      pkgs.rust-analyzer
      # pkgs.lldb

      # TYPESCRIPT & OTHERS
      pkgs.deno

      # YAML
      pkgs.yaml-language-server

      # ZIG
      pkgs.zls
    ];
  };
}
