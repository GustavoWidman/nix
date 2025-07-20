{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) attrValues optionalAttrs;
in
{
  environment.systemPackages =
    attrValues
    <|
      {
        inherit (pkgs)
          age
          awscli2
          bash
          bat
          binwalk
          coreutils
          dosfstools
          e2fsprogs
          fastfetch
          fzf
          gcc
          go
          hping
          htop
          httpie
          nano
          netcat-gnu
          nmap
          openfortivpn
          openssl_3
          openvpn
          p7zip
          python313
          ripgrep
          rustscan
          socat
          sops
          sqlite
          stow # ! TODO maybe remove this if we fully port to nix
          util-linux
          wget
          wireguard-tools

          # asciinema
          # cowsay
          # curlHTTP3
          # dig
          # doggo
          # eza
          # fastfetch
          # fd
          # hyperfine
          # jc
          # moreutils
          # openssl
          # p7zip
          # pstree
          # rsync
          # sd
          # timg
          # tokei
          # typos
          # uutils-coreutils-noprefix
          # xh
          # yazi
          # yt-dlp
          ;

        # fortune = pkgs.fortune.override { withOffensive = true; };
      }
      // optionalAttrs config.isLinux {
        inherit (pkgs)
          usbutils
          tailscale
          ;
      }
      // optionalAttrs config.isDarwin {
        inherit (pkgs)
          alt-tab-macos
          iproute2mac
          lima
          llama-cpp
          maccy
          # macfuse # TODO
          stats
          swift-quit
          unnaturalscrollwheels
          utm
          ;
      }
      // optionalAttrs config.isDesktop {
        inherit (pkgs)
          abseil-cpp
          arduino-cli
          biome

          clang
          clang-tools
          cmake

          cyme
          dalfox
          dbeaver-bin
          discord # TODO make own config of this maybe?
          exploitdb
          feroxbuster # TODO make own config of this
          ffuf
          freetds
          gdb
          # ghostty-bin # TODO make own config of this
          gradle
          hashcat
          # httpie-desktop #! TODO not compatible with macos
          jdk
          john
          llvm
          lua
          maven
          metasploit
          mitmproxy
          nuclei
          oha # ! TODO maybe remove this
          postgresql
          qemu
          radare2
          # retdec #! TODO not compatible with macos
          sqlmap
          terraform
          # tldr # TODO do i use this?
          tree # ? TODO swap this for rgbcube's thing
          wireshark
          yq
          yt-dlp

          # claude-code

          # clang_16
          # clang-tools_16
          # deno
          # gh
          # go
          # lld
          # zig

          # qbittorrent
          ;
      };
  # // optionalAttrs (config.isLinux && config.isDesktop) {
  #   inherit (pkgs)
  #     # thunderbird

  #     # whatsapp-for-linux

  #     # element-desktop
  #     # zulip
  #     # fractal

  #     # obs-studio

  #     # krita

  #     # libreoffice
  #   ;

  #   # inherit (pkgs.hunspellDicts)
  #   #   en_US
  #   #   en_GB-ize
  #   # ;
  # };
}
