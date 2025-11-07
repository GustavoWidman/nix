{
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    pkgs.rift
  ];

  services.rift = {
    config = ./config.toml;
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
