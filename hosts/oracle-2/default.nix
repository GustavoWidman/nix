lib:
lib.nixosSystem' (
  {
    config,
    keys,
    lib,
    modulesPath,
    pkgs,
    ...
  }:
  let
    inherit (lib) collectNix remove;
  in
  {
    imports = collectNix ./. |> remove ./default.nix;

    networking.hostName = "oracle-2";

    secrets.password.file = ./password.age;
    users.users = {
      root = {
        hashedPasswordFile = config.secrets.password.path;
        openssh.authorizedKeys.keys = keys.admins;
        shell = pkgs.nushell;
      };

      r3dlust = {
        hashedPasswordFile = config.secrets.password.path;
        authorizedKey = config.secrets.ssh-oracle-oracle-2.path;
        shell = pkgs.nushell;

        isMainUser = true;
        isNormalUser = true;

        name = "r3dlust";
        home = "/home/r3dlust";
        extraGroups = [ "wheel" ];
      };

      build = {
        hashedPasswordFile = config.secrets.password.path;
        openssh.authorizedKeys.keys = keys.all;

        isNormalUser = true;

        extraGroups = [ "build" ];
      };
    };

    time.timeZone = "America/Sao_Paulo";
    home-manager.users = {
      root.home = {
        stateVersion = "25.05";
        homeDirectory = "/root";
      };

      r3dlust.home = {
        stateVersion = "25.05";
        homeDirectory = "/home/r3dlust";
      };
    };
    system.stateVersion = "25.05";
  }
)
