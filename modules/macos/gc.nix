{
  lib,
  config,
  ...
}:
let
  cfg = config.services.nh-clean;
  extraArgsList = lib.filter (s: s != "") (lib.splitString " " cfg.extraArgs);
  nhCleanExec = lib.concatStringsSep " " (
    [
      (lib.getExe cfg.package)
      "clean"
      "all"
    ]
    ++ extraArgsList
  );
in
{
  launchd.daemons.nh-clean = {
    serviceConfig = {
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "/bin/wait4path /nix/store && exec ${nhCleanExec}"
      ];

      EnvironmentVariables = {
        PATH = "/usr/bin:/bin:/usr/sbin:/sbin:/nix/var/nix/profiles/default/bin";
      };

      StartCalendarInterval = cfg.interval;
      StandardOutPath = "/var/log/nh-clean.log";
      StandardErrorPath = "/var/log/nh-clean.error.log";
      RunAtLoad = false;
      LowPriorityIO = true;
      ProcessType = "Background";
    };
  };
}
