{ pkgs, arion, ... }:
{
  imports = [
    arion.nixosModules.arion
  ];

  environment.systemPackages = with pkgs; [
    arion
    docker-client
  ];

  virtualisation.arion.backend = "docker";
}
