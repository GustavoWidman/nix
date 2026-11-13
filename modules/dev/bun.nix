{ pkgs, portfolio, ... }:

{
  # The portfolio input exports the patched Bun overlay.
  # Do not restore the old local 1.3.x override: it predates CVE-2026-111497.
  nixpkgs.overlays = [ portfolio.overlays.default ];

  home-manager.sharedModules = [
    {
      programs.bun = {
        enable = true;
        package = pkgs.bun;
      };
    }
  ];
}
