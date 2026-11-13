{ pkgs, arion, ... }:
{
  imports = [
    arion.nixosModules.arion
  ];
  nixpkgs.overlays = [ arion.overlays.default ];

  environment.systemPackages = with pkgs; [
    arion
    docker-client
  ];

  virtualisation.arion.backend = "docker";
}
