{
  lib,
  pkgs,
  ...
}:
{
  options.services.nh-clean = {
    enable = lib.mkEnableOption "periodic garbage collection with nh clean all";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nh;
      description = "The nh package to use for cleaning.";
    };

    dates = lib.mkOption {
      type = lib.types.singleLineStr;
      default = "weekly";
      description = ''
        (Linux only) How often cleanup is performed. Passed to systemd.time.
        The format is described in {manpage}`systemd.time(7)`.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.int);
      default = [
        {
          Weekday = 0;
          Hour = 3;
          Minute = 0;
        }
      ];
      example = lib.literalExpression "[ { Hour = 3; Minute = 15; } ]";
      description = ''
        (macOS only) When to run `nh clean all`, expressed as a list of
        launchd StartCalendarInterval attribute sets.

        Missing keys are treated as wildcards (like crontab). If the machine
        is asleep at the scheduled time, launchd fires the job on next wake.

        See {manpage}`launchd.plist(5)` for the full key reference.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.singleLineStr;
      default = "";
      example = "--keep 5 --keep-since 3d";
      description = ''
        Extra options passed to `nh clean all` when run automatically.
      '';
    };
  };
}
