{ ... }:

{
  home-manager.sharedModules = [
    {
      programs.uv.enable = true;
    }
  ];
}
