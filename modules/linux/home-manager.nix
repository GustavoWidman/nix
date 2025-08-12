{ ... }:

{
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
}
