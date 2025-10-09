{ pkgs, ... }:
{
  system.defaults.loginwindow = {
    DisableConsoleAccess = true;
    GuestEnabled = false;
  };

  system.login-items = with pkgs; [
    unnaturalscrollwheels
    stats
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
