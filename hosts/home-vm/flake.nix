parent:
let
  metadata = {
    hostname = "home-vm";
    class = "nixos";
    type = "dev-server";
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
      inputs.lib.linuxDevServerSystem inputs (
        {
          config,
          lib,
          ...
        }:
        let
          inherit (lib) collectNix remove;

          extra-platforms = metadata.build-architectures |> remove metadata.architecture;
        in
        {
          inherit metadata;

          imports = collectNix ./. |> remove ./flake.nix;

          networking.hostName = metadata.hostname;
          nixpkgs.hostPlatform = metadata.architecture;

          users.users.r3dlust.authorizedKey = config.secrets.ssh-vms-vm.path;
          secrets.password.file = ./password.age;

          time.timeZone = "America/Sao_Paulo";
          system.stateVersion = "25.05";

          nix.settings.extra-platforms = extra-platforms;
          boot.binfmt.emulatedSystems = extra-platforms;
        }
      );
  };
}
