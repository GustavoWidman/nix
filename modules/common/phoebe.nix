# phoebe, the fleet's metrics, logs and alerts: every machine runs its agent,
# and the nodes in lib.phoebeFleet also store everything and alert. its
# module comes from lib/system.nix's fleetInputs.
{ config, lib, ... }:
{
  services.phoebe = {
    enable = lib.phoebeFleet.machines ? ${config.networking.hostName};
    fleet = lib.phoebeFleet;
  };
}
