{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
in
{
  config.environment = {
    systemPackages = mkIf config.isDev [
      # BASH
      pkgs.bash-language-server

      # CADDY
      pkgs.caddy

      # CMAKE
      pkgs.cmake-language-server

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
      pkgs.nixfmt
      pkgs.nixd

      # PYTHON
      pkgs.basedpyright

      # RUST
      # see `modules/dev/rust.nix` for this

      # TYPESCRIPT & OTHERS
      pkgs.deno

      # YAML
      pkgs.yaml-language-server

      # ZIG
      pkgs.zls
    ];
  };
}
