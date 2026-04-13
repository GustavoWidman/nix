parent:
let
  metadata = {
    hostname = "oracle-1";
    class = "nixos";
    type = "server";
    architecture = "aarch64-linux";
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
          users.users.r3dlust.authorizedKey = config.secrets.ssh-oracle-oracle-1.path;

          time.timeZone = "America/Sao_Paulo";
          system.stateVersion = "25.11";

          networking.firewall = {
            allowedTCPPorts = [
              80
              443
            ];
            allowedUDPPorts = [ 443 ];
          };

          tailscale.exit-node = true;
        }
      );
  };
}
