parent:
let
  hostname = "lab";
  class = "nixos";
  type = "server";
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
      inputs.lib.linuxServerSystem inputs (
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

          secrets.password.file = ./password.age;
          users.users.r3dlust.authorizedKey = config.secrets.ssh-main-lab.path;

          time.timeZone = "America/Sao_Paulo";
          system.stateVersion = "25.05";

          nixpkgs.hostPlatform = architecture;
        }
      );
  };
}
