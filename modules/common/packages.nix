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
          attic-client
          age
          # awscli2 # TODO broken
          bash
          binwalk
          cachix
          # coreutils
          curl
          dig
          dosfstools
          e2fsprogs
          exfat
          eza
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
          util-linux
          uutils-coreutils-noprefix
          uutils-findutils
          watchexec
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
          wol
          ;
      }
      // optionalAttrs config.isDarwin {
        lima = pkgs.lima.override {
          withAdditionalGuestAgents = true;
        };
        inherit (pkgs)
          fuse-ext2
          iproute2mac
          libiconv
          lima-additional-guestagents
          llama-cpp
          sshfs
          unnaturalscrollwheels
          utm
          ;
      }
      // optionalAttrs config.isDev {
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
          jdk
          john
          lua
          nasm
          nasmfmt
          maven
          manix
          metasploit
          mitmproxy
          nuclei
          postgresql
          qemu
          radare2
          # retdec #! TODO not compatible with macos
          sqlmap
          terraform
          tldr
          # -------------------------------------- #
          # wireshark # TODO broken
          termshark # wireshark substiture for now
          tshark
          # -------------------------------------- #
          yq
          yt-dlp
          ;
        inherit (pkgs.llvmPackages)
          llvm
          ;
      };
}
