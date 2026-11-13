{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) attrValues mkIf mkMerge;
in
{
  environment.systemPackages = mkMerge [
    (attrValues {
      lima = pkgs.lima.override {
        withAdditionalGuestAgents = true;
      };
      inherit (pkgs)
        # fuse-ext2
        iproute2mac
        libiconv
        lima-additional-guestagents
        llama-cpp
        sshfs
        unnaturalscrollwheels
        utm
        ;
    })
    (mkIf config.isDesktop [
      pkgs.terminal-notifier
      pkgs.texliveFull
    ])
  ];
}
