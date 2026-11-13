{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) attrValues;
in
{
  environment.systemPackages =
    attrValues
    <| {
      inherit (pkgs)
        attic-client
        age
        awscli2 # TODO broken
        binwalk
        cachix
        # coreutils
        curl
        dig
        dosfstools
        e2fsprogs
        eza
        fastfetch
        file
        ffmpeg
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
        niks3
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
    };
}
