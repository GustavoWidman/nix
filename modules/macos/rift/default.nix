{
  config,
  pkgs,
  lib,
  fenix,
  crane,
  rift,
  ...
}:
let
  riftOverlay = final: prev: {
    rift =
      let
        toolchain = fenix.packages.${config.metadata.architecture}.default.toolchain;
        craneLib = (crane.mkLib final).overrideToolchain toolchain;
        src = rift;

        commonArgs = {
          inherit src;
          pname = "rift";
          version = src.rev or "unstable";
          buildInputs = [ ];
          doCheck = false; # disable tests for now
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
      in
      craneLib.buildPackage (commonArgs // { cargoArtifacts = cargoArtifacts; });
  };
in
{
  nixpkgs.overlays = [ riftOverlay ];

  environment.systemPackages = [
    pkgs.rift
  ];

  # system.activationScripts.rift.text = ''
  #   ${pkgs.rift}/bin/rift service install
  #   ${pkgs.rift}/bin/rift service restart
  # '';

  home-manager.sharedModules = [
    {
      xdg.configFile."rift/config.toml".source = ./config.toml;
    }
  ];
}
