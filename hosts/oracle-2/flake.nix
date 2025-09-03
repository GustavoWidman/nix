parent:
let
  hostname = "oracle-2";
  class = "nixos";
  type = "server";
  architecture = "aarch64-linux";
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
          users.users.r3dlust.authorizedKey = config.secrets.ssh-oracle-oracle-2.path;

          time.timeZone = "America/Sao_Paulo";
          system.stateVersion = "25.05";

          nixpkgs.hostPlatform = architecture;
        }
      );
  };
}
