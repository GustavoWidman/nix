{ pkgs, ... }:
let
  altTabScript = pkgs.writeText "alttab.scpt" ''
    tell application "Terminal"
    	  do script "screen -dmS AltTab ${pkgs.alt-tab-macos}/Applications/AltTab.app/Contents/MacOS/AltTab"
      delay 1.5
      if it is running then quit
    end tell
  '';
in
{
  system.defaults.loginwindow = {
    DisableConsoleAccess = true;
    GuestEnabled = false;
  };

  system.login-items = with pkgs; [
    unnaturalscrollwheels
    stats
    {
      package = pkgs.alt-tab-macos;
      command = "/usr/bin/osascript ${altTabScript}";
      keepAlive = false;
    }
  ];

}
