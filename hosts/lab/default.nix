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
    inherit (lib) collectNix remove readFile;
  in
  {
    imports = collectNix ./. |> remove ./default.nix;

    networking.hostName = "lab";

    secrets.password.file = ./password.age;
    users.users = {
      root = {
        hashedPasswordFile = config.secrets.password.path;
        openssh.authorizedKeys.keys = keys.admins;
        shell = pkgs.nushell;
      };

      r3dlust = {
        hashedPasswordFile = config.secrets.password.path;
        shell = pkgs.nushell;
        authorizedKey = config.secrets.ssh-cfg-main-lab.path;

        name = "r3dlust";
        home = "/home/r3dlust";
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };
    };

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
    system.stateVersion = "25.11";

    nixpkgs.hostPlatform = "x86_64-linux";
  }
)
