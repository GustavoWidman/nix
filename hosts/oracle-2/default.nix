lib:
lib.linuxServerSystem (
  {
    config,
    lib,
    ...
  }:
  let
    inherit (lib) collectNix remove;
  in
  {
    imports = collectNix ./. |> remove ./default.nix;
    type = "server";

    networking.hostName = "oracle-2";

    secrets.password.file = ./password.age;
    users.users.r3dlust.authorizedKey = config.secrets.ssh-oracle-oracle-2.path;

    time.timeZone = "America/Sao_Paulo";
    system.stateVersion = "25.05";

    nixpkgs.hostPlatform = "aarch64-linux";
  }
)
