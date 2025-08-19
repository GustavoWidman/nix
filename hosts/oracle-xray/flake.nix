parent:
let
  metadata = {
    hostname = "oracle-xray";
    class = "nixos";
    type = "server";
    architecture = "x86_64-linux";
    build-architectures = [ ]; # this guy is too tiny to build
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
          users.users.r3dlust.authorizedKey = config.secrets.ssh-oracle-oracle-xray.path;

          time.timeZone = "America/Sao_Paulo";
          system.stateVersion = "25.05";

          tailscale.exit-node = true;
        }
      );
  };
}
