{
  config,
  lib,
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
  systemd = lib.mkIf cfg.enable {
    services.nh-clean = {
      description = "nh clean all (periodic Nix GC)";
      script = "exec ${nhCleanExec}";
      startAt = cfg.dates;
      path = [ config.nix.package ];
      after = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
    };
    timers.nh-clean.timerConfig.Persistent = true;
  };
}
