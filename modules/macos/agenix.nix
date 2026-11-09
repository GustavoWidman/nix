{
  config,
  lib,
  pkgs,
  ...
}:
{
  # agenix keeps its secrets on a RAM disk with a fixed size of 512 MB, all of
  # which stays resident for as long as the disk is mounted. The secrets take
  # a few hundred kilobytes, so 16 MB leaves plenty of room.
  launchd.daemons.activate-agenix.command = lib.mkForce (
    pkgs.writeShellScript "activate-agenix-start" (
      lib.replaceStrings [ "num_sectors=1048576" ] [ "num_sectors=32768" ]
        config.launchd.daemons.activate-agenix.script
    )
  );
}
