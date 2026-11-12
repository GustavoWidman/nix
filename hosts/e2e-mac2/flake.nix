parent:
let
  metadata = {
    hostname = "e2e-mac2";
    class = "darwin";
    type = "server";
    architecture = "aarch64-darwin";
    build-architectures = [
      metadata.architecture
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
      inputs.lib.darwinServerSystem inputs (
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          inherit (lib) collectNix remove;
        in
        {
          inherit metadata;

          imports = collectNix ./. |> remove ./flake.nix;

          networking.hostName = metadata.hostname;
          nixpkgs.hostPlatform = metadata.architecture;

          users.users = {
            admin = {
              name = "admin";
              home = "/Users/admin";
              isMainUser = true;
              shell = pkgs.nushell;
              authorizedKey = config.secrets.ssh-main-e2e-mac2.path;
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

            admin.home = {
              stateVersion = "25.05";
              homeDirectory = "/Users/admin";
            };
          };

          tailscale.enable = true;

          system.stateVersion = 6;
        }
      );
  };
}
