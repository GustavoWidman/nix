{
  config,
  lib,
  pkgs,
  ...
}:
{
  system.defaults.loginwindow = {
    DisableConsoleAccess = true;
    GuestEnabled = false;
  };

  launchd.user.agents = lib.mkIf config.isDesktop (
    lib.mapAttrs
      (name: bundle: {
        command = "${pkgs.${name}}/Applications/${bundle}.app/Contents/MacOS/${bundle}";
        serviceConfig = {
          RunAtLoad = true;
          KeepAlive = true;
          ProcessType = "Interactive";
        };
      })
      {
        stats = "Stats";
        unnaturalscrollwheels = "UnnaturalScrollWheels";
      }
  );

  launchd.daemons.limit-maxfiles = {
    serviceConfig.ProgramArguments = [
      "launchctl"
      "limit"
      "maxfiles"
      "65536"
      "unlimited"
    ];
    serviceConfig.RunAtLoad = true;
  };
}
