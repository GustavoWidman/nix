parent:
let
  metadata = {
    hostname = "e2e-linux";
    class = "nixos";
    type = "server";
    architecture = "x86_64-linux";
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
      inputs.lib.linuxServerSystem inputs (
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

          secrets.password.file = ./password.age;
          users.users.r3dlust.authorizedKey = config.secrets.ssh-main-e2e-linux.path;

          time.timeZone = "America/Sao_Paulo";
          system.stateVersion = "26.05";
        }
      );
  };
}
