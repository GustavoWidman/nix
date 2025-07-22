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
          binwalk
          # coreutils
          curlHTTP3
          dig
          dosfstools
          e2fsprogs
          fastfetch
          fzf
          gcc
          go
          hping
          htop
          httpie
          jq
          nano
          netcat-gnu
          nmap
          openfortivpn
          openssl
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
          uutils-coreutils-noprefix
          uutils-findutils
          wget
          wireguard-tools
          ;
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
          manix
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
          ;
      };
}
