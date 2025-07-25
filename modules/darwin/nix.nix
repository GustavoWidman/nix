{ pkgs, lib, ... }:
let
  inherit (lib)
    mkForce
    ;
in
{
  # nix.linux-builder = {
  #   enable = true;
  #   systems = [
  #     "x86_64-linux"
  #     "aarch64-linux"
  #   ];
  #   ephemeral = true;
  #   package = pkgs.darwin.linux-builder;
  #   supportedFeatures = [
  #     "kvm"
  #     "benchmark"
  #     "big-parallel"
  #     "nixos-test"
  #   ];
  #   maxJobs = 8;

  #   config = {
  #     # Enable x86_64 emulation via binfmt/qemu
  #     boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
  #     # Or use Rosetta if available
  #     nix.settings.extra-platforms = [ "x86_64-linux" ];

  #     virtualisation.cores = 8;
  #     virtualisation.memorySize = mkForce 16384; # 16GB
  #   };
  # };
  # launchd.daemons.linux-builder = {
  #   serviceConfig = {
  #     StandardOutPath = "/var/log/darwin-builder.log";
  #     StandardErrorPath = "/var/log/darwin-builder.log";
  #   };
  # };
}
