{
  config,
  lib,
  self,
  ...
}:
{
  cloudflare.zones = [
    "guswid.com"
    "r3dlust.com"
    "rockyclan.com"
  ];

  services.norn = {
    peers = lib.mapAttrs (_: machine: machine.config.cloudflare.claims) (
      self.nixosConfigurations // self.darwinConfigurations
    );
    # changes reach cloudflare on the switch itself, so the sweep only repairs
    # hand edits and retries failed runs. keep it under 30 minutes, where
    # `norn status` starts treating a quiet norn as troubled
    interval = 15 * 60;
    # orders the fleet's shared records: a newer commit outranks an older one,
    # and a build of an uncommitted tree never writes them
    revision = if self ? rev then self.lastModified else null;
    # coeusd rewrites it whenever it looks `deployed` up, and `deployed` moves
    # only once every reachable machine runs the commit, so a shared record
    # is deleted only after the whole fleet stopped declaring it
    rollout.file = config.services.coeus.follow.stateFile;
  };
}
