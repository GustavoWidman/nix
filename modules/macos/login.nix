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

  system.login-items = lib.mkIf config.isDesktop [
    pkgs.unnaturalscrollwheels
    pkgs.stats
  ];

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
