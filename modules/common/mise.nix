{ ... }:

{
  home-manager.sharedModules = [
    {
      programs.mise = {
        enable = true;
        # settings = {} # TODO
        enableNushellIntegration = false;
      };
    }
  ];
}
