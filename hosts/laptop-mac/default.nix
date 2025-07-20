lib:
lib.darwinSystem' (
  {
    lib,
    pkgs,
    ...
  }:
  let
    inherit (lib) collectNix remove;
  in
  {
    imports = collectNix ./. |> remove ./default.nix;

    type = "desktop";

    networking.hostName = "laptop-mac";

    users.users.r3dlust = {
      name = "r3dlust";
      home = "/Users/r3dlust";
      shell = pkgs.nushell;
    };

    home-manager.users.r3dlust.home = {
      stateVersion = "25.05";
      homeDirectory = "/Users/r3dlust";
    };

    system.stateVersion = 5;
  }
)
