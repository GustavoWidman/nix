# phoebe, the fleet's metrics, logs and alerts: every machine runs its agent,
# and the nodes in lib.phoebeFleet also store everything and alert. its
# module comes from lib/system.nix's fleetInputs.
{ config, lib, ... }:
{
  services.phoebe = {
    enable = lib.phoebeFleet.machines ? ${config.networking.hostName};
    fleet = lib.phoebeFleet;
    # lab's and altar's disks run close to full, so a node's metrics stop at
    # 10 GB, whichever comes first of that and the 90 days phoebe keeps
    node.retention.metricsSize = "10GB";
  };
}
