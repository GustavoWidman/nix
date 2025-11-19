parent:
let
  metadata = {
    hostname = "lab";
    class = "nixos";
    type = "dev-server";
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

          secrets.password.file = ./password.age;
          users.users.r3dlust.authorizedKey = config.secrets.ssh-main-lab.path;

          time.timeZone = "America/Sao_Paulo";
          system.stateVersion = "25.05";

          nix.settings.extra-platforms = extra-platforms;
          boot.binfmt.emulatedSystems = extra-platforms;

          tailscale = {
            exit-node = true;
            advertise-routes = [
              "192.168.101.0/24"
            ];
          };
        }
      );
  };
}
