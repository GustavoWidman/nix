{ pkgs, arion, ... }:
{
  imports = [
    arion.nixosModules.arion
  ];

  environment.systemPackages = with pkgs; [
    arion
    docker-client
  ];

  virtualisation.arion = {
    backend = "docker";
    # nixpkgs' arion is the same release, built by Hydra; the module's default
    # builds arion's flake from source, with callCabal2nix at evaluation time
    package = pkgs.arion;
  };
}
