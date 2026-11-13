{ pkgs, ... }:

{
  users.users.root = {
    home = "/var/root";
    shell = pkgs.nushell;
  };

  home-manager.users.root = { };
}
