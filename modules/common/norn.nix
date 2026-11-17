{ lib, self, ... }:
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
  };
}
