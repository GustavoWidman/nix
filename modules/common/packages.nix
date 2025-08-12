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
          exfat
          fastfetch
          file
          fzf
          gawk
          gcc
          gnused
          go
          hping
          htop
          httpie
          jq
          lsof
          nano
          netcat-gnu
          nmap
          openfortivpn
          openssl
          openvpn
          p7zip
          python313
          q
          ripgrep
          rsync
          rustscan
          socat
          sops
          sqlite
          stow # ! TODO maybe remove this if we fully port to nix
          tree # ? TODO swap this for rgbcube's eza thing
          util-linux
          uutils-coreutils-noprefix
          uutils-findutils
          wget
          wireguard-tools
          ;
      }
      // optionalAttrs config.isLinux {
        inherit (pkgs)
          inotify-tools
          tailscale
          usbutils
          xfsprogs
          ;
      }
      // optionalAttrs config.isDarwin {
        inherit (pkgs)
          alt-tab-macos
          fuse-ext2
          iproute2mac
          libiconv
          lima
          llama-cpp
          sshfs
          stats
          unnaturalscrollwheels
          utm
          ;
      }
      // optionalAttrs config.isDev {
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
          # discord # TODO make own config of this maybe? #! THIS IS BROKEN ON MAC FOR SOME REASON
          exploitdb
          feroxbuster # TODO make own config of this
          ffuf
          gdb
          gradle
          hashcat
          # httpie-desktop #! TODO not compatible with macos
          jdk
          john
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
          wireshark
          yq
          yt-dlp
          ;
        inherit (pkgs.llvmPackages)
          llvm
          ;
      };
}
