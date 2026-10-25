{ pkgs, ... }:

{
  # The portfolio input exports the patched Bun overlay for all host packages.
  # Do not restore the old local 1.3.x override: it predates CVE-2026-111497.
  home-manager.sharedModules = [
    {
      programs.bun = {
        enable = true;
        package = pkgs.bun;
      };
    }
  ];
}
