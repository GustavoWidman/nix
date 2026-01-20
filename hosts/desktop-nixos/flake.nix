parent:
let
  metadata = {
    hostname = "desktop-nixos";
    class = "nixos";
    type = "desktop";
    architecture = "x86_64-linux";
    build-architectures = [ ]; # no builds, not always on
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
      inputs.lib.linuxDesktopSystem inputs (
        {
          config,
          pkgs,
          lib,
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

          users.users.r3dlust.authorizedKey = config.secrets.ssh-main-desktop.path;
          secrets.password.file = ./password.age;

          time.timeZone = "America/Sao_Paulo";
          system.stateVersion = "25.11";

          networking.networkmanager.enable = true;
          environment.systemPackages = [
            pkgs.sbctl
          ];
        }
      );
  };
}
