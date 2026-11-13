{
  lib,
  pkgs,
  ...
}:
{
  # nix-darwin's programs.nh.clean requires nix.enable, which Determinate turns off
  launchd.daemons.nh-clean.serviceConfig = {
    ProgramArguments = [
      "/bin/sh"
      "-c"
      "/bin/wait4path /nix/store && exec ${lib.getExe pkgs.nh} clean all"
    ];

    EnvironmentVariables = {
      PATH = "/usr/bin:/bin:/usr/sbin:/sbin:/nix/var/nix/profiles/default/bin";
    };

    StartCalendarInterval = [
      {
        Weekday = 0;
        Hour = 3;
        Minute = 0;
      }
    ];
    StandardOutPath = "/var/log/nh-clean.log";
    StandardErrorPath = "/var/log/nh-clean.error.log";
    RunAtLoad = false;
    LowPriorityIO = true;
    ProcessType = "Background";
  };
}
