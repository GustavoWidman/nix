parent:
let
  metadata = {
    hostname = "oracle-2";
    class = "nixos";
    type = "server";
    architecture = "aarch64-linux";
    build-architectures = [
      metadata.architecture
    ];
  };
in
{
  inputs = parent // {
    dailybot = parent.lib.fetchGitFlake {
      owner = "camelsec";
      repo = "dailybot";
      ssh = true;
      rev = "4e4ff35e85ab226095ed0a114c6d245874871422";
    };
  };

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
          users.users.r3dlust.authorizedKey = config.secrets.ssh-oracle-oracle-2.path;

          time.timeZone = "America/Sao_Paulo";
          system.stateVersion = "25.05";
        }
      );
  };
}
