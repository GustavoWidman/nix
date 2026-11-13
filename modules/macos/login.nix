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
    lib.genAttrs [ "stats" "unnaturalscrollwheels" ] (name: {
      command = "${pkgs.${name}}/Applications/${name}.app/Contents/MacOS/${name}";
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Interactive";
      };
    })
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
