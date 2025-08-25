{
  pkgs,
  ...
}:

{
  home-manager.sharedModules = [
    {
      programs.bun = {
        enable = true;
        package = pkgs.bun;
      };
    }
  ];
}
