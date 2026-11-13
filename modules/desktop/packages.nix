{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.dbeaver-bin
    pkgs.obsidian
    pkgs.pandoc
    pkgs.wireshark
  ];
}
