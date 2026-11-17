{ lib, self, ... }:
{
  cloudflare.zones = [
    "guswid.com"
    "r3dlust.com"
    "rockyclan.com"
  ];

  services.norn.peers = lib.mapAttrs (_: machine: machine.config.cloudflare.claims) (
    self.nixosConfigurations // self.darwinConfigurations
  );
}
