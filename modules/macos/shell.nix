{ pkgs, ... }:

{
  environment.shells = [ pkgs.nushell ];

  home-manager.sharedModules = [
    {
      home.file."Library/Application Support/nushell/autoload" = {
        source = ./nushell;
        recursive = true;
        force = true;
      };
    }
  ];
}
