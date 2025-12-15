{
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    pkgs.rift-bin
  ];

  services.rift = {
    # enable = true;
    config = ./config.toml;
    package = pkgs.rift-bin;
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
