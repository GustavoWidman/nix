parent:
let
  hostname = "home-vm";
  class = "nixos";
  type = "dev-server";
  architecture = "x86_64-linux";
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
      inputs.lib.linuxDevServerSystem inputs (
        {
          config,
          lib,
          ...
        }:
        let
          inherit (lib) collectNix remove;
        in
        {
          inherit type;

          imports = collectNix ./. |> remove ./flake.nix;

          networking.hostName = hostname;

          users.users.r3dlust.authorizedKey = config.secrets.ssh-vms-vm.path;
          secrets.password.file = ./password.age;

          time.timeZone = "America/Sao_Paulo";
          system.stateVersion = "25.05";

          nixpkgs.hostPlatform = architecture;

          nix.settings.extra-platforms = [ "aarch64-linux" ];
          boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
        }
      );
  };
}
