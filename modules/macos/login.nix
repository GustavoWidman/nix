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
}
