{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) attrValues enabled;
in
{
  environment.systemPackages =
    attrValues {
      penelope = pkgs.penelope.overrideAttrs (oldAttrs: {
        version = "0.14.8";
        src = pkgs.fetchFromGitHub {
          owner = "brightio";
          repo = "penelope";
          rev = "v0.14.8";
          hash = "sha256-m4EYP1lKte8r9Xa/xAuv6aiwMNha+B8HXUCizH0JgmI=";
        };
      });
      inherit (pkgs)
        abseil-cpp
        agenix
        arduino-cli
        biome
        clang
        clang-tools
        cmake
        cyme
        dalfox
        # discord # TODO make own config of this maybe? #! THIS IS BROKEN ON MAC FOR SOME REASON
        exploitdb
        feroxbuster # TODO make own config of this
        ffuf
        # gdb # TODO broken on nixpkgs
        gradle
        glab
        hashcat
        jdk
        john
        just
        libbde
        lua
        nasm
        nasmfmt
        maven
        manix
        metasploit
        mitmproxy
        nodejs_26
        nuclei
        oxfmt
        oxlint
        portaudio
        postgresql
        qemu
        radare2
        # retdec #! TODO not compatible with macos
        sqlmap
        tectonic
        terraform
        termshark
        testdisk
        tshark
        tldr
        typescript-language-server
        typst
        typstyle
        yq
        yt-dlp
        ;
      inherit (pkgs.llvmPackages)
        llvm
        ;
    }
    # language servers and formatters for helix
    ++ [
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

  home-manager.sharedModules = [
    {
      programs.gh = enabled {
        settings.git_protocol = "ssh";
      };
    }
  ];
}
