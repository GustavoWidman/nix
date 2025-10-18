parent:
let
  metadata = {
    hostname = "laptop-mac";
    class = "darwin";
    type = "desktop";
    architecture = "aarch64-darwin";
    build-architectures = [
      metadata.architecture
      "x86_64-darwin"
    ];
  };
in
{
  inputs = parent;

  outputs = {
    inherit metadata;

    config =
      inputs@{
        ...
      }:
      inputs.lib.darwinDesktopSystem inputs (
        { lib, pkgs, ... }:
        let
          inherit (lib)
            collectNix
            remove
            ;

          extra-platforms = metadata.build-architectures |> remove metadata.architecture;
        in
        {
          inherit metadata;

          imports = collectNix ./. |> remove ./flake.nix;

          networking.hostName = metadata.hostname;
          nixpkgs.hostPlatform = metadata.architecture;

          users.users = {
            r3dlust = {
              name = "r3dlust";
              home = "/Users/r3dlust";
              isMainUser = true;
              shell = pkgs.nushell;
            };

            root = {
              name = "root";
              home = "/var/root";
              shell = pkgs.nushell;
            };
          };

          home-manager.users = {
            root.home = {
              stateVersion = "25.05";
              homeDirectory = "/var/root";
            };

            r3dlust.home = {
              stateVersion = "25.05";
              homeDirectory = "/Users/r3dlust";
            };
          };

          system.stateVersion = 5;

          nix.settings.extra-platforms = extra-platforms;
        }
      );
  };
}
