{
  pkgs,
  rift,
  ...
}:
{
  services.rift = {
    enable = true;
    config = ./config.toml;
    # Build the fork so native tab focus fixes are included.
    package = rift.packages.${pkgs.stdenv.hostPlatform.system}.rift;
  };

  # system.activationScripts.rift.text = ''
  #   ${pkgs.rift}/bin/rift service install
  #   ${pkgs.rift}/bin/rift service restart
  # '';

  home-manager.sharedModules = [
    {
      xdg.configFile."rift/config.toml".source = ./config.toml;
    }
  ];
}
