lib:
lib.linuxDevServerSystem (
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
    type = "dev-server";

    networking.hostName = "home-vm";

    users.users.r3dlust.authorizedKey = config.secrets.ssh-vms-vm.path;
    secrets.password.file = ./password.age;

    time.timeZone = "America/Sao_Paulo";
    system.stateVersion = "25.05";

    nixpkgs.hostPlatform = "x86_64-linux";
  }
)
