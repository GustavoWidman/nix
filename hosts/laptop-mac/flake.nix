parent:
let
  hostname = "laptop-mac";
  class = "darwin";
  type = "desktop";
  architecture = "aarch64-darwin";
in
{
  inputs = parent;

  outputs = {
    metadata = {
      inherit
        hostname
        class
        type
        architecture
        ;
    };

    config =
      inputs@{
        ...
      }:
      inputs.lib.darwinDesktopSystem inputs (
        { lib, pkgs, ... }:
        {
          inherit type;

          imports = lib.collectNix ./. |> lib.remove ./flake.nix;

          networking.hostName = hostname;

          users.users.r3dlust = {
            name = "r3dlust";
            home = "/Users/r3dlust";
            isMainUser = true;
            shell = pkgs.nushell;
          };

          home-manager.users.r3dlust.home = {
            stateVersion = "25.05";
            homeDirectory = "/Users/r3dlust";
          };

          system.stateVersion = 5;
          nix.settings.extra-platforms = [ "x86_64-darwin" ];
          nixpkgs.hostPlatform = architecture;
        }
      );
  };
}
