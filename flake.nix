{
  description = "r3dlust's Nix Config Collection";

  nixConfig = {
    extra-substituters = [
      "https://install.determinate.systems"
      "https://cache.garnix.io"
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];

    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "determinate-systems.cachix.org-1:8hfO/4KM4BUMONABo3NyuTsIB9YLUo5aIwGPg2A6Zs4="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    ];

    experimental-features = [
      "cgroups"
      "flakes"
      "nix-command"
      "pipe-operators"
      "build-time-fetch-tree"
    ];

    builders-use-substitutes = true;
    keep-outputs = true;
    flake-registry = "";
    http-connections = 50;
    max-substitution-jobs = 50;
    show-trace = true;
    trusted-users = [
      "root"
      "@build"
      "@wheel"
      "@admin"
    ];
    lazy-trees = true;
    use-cgroups = true;
    warn-dirty = false;
  };

  inputs = {
    self.submodules = true;

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.darwin.follows = "nix-darwin";
      inputs.home-manager.follows = "home-manager";
    };

    nix.url = "https://flakehub.com/f/DeterminateSystems/nix-src/*";

    nh = {
      url = "github:nix-community/nh/v4.2.0-beta2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ nixpkgs, nix-darwin, ... }:
    let
      inherit (builtins) readDir;
      inherit (nixpkgs.lib)
        attrsToList
        const
        groupBy
        listToAttrs
        mapAttrs
        nameValuePair
        ;

      lib = (nixpkgs.lib.extend (const <| const <| nix-darwin.lib)).extend <| import ./lib inputs;

      machineFlakes =
        readDir ./hosts
        |> mapAttrs (name: const <| (import ./hosts/${name}/flake.nix (inputs // { inherit lib; })));

      machineMetadata = machineFlakes |> mapAttrs (name: flake: flake.outputs.metadata);

      hostsByType =
        machineFlakes
        |> mapAttrs (
          name: flake:
          (flake.outputs.config flake.inputs)
          // {
            inherit (flake.outputs) metadata;
          }
        )
        |> attrsToList
        |> groupBy (
          { value, ... }:
          if value.metadata.class == "nixos" then "nixosConfigurations" else "darwinConfigurations"
        )
        |> mapAttrs (const listToAttrs);

      hostConfigs =
        hostsByType.darwinConfigurations // hostsByType.nixosConfigurations
        |> attrsToList
        |> map ({ name, value }: nameValuePair name value.config)
        |> listToAttrs;
    in
    hostsByType
    // hostConfigs
    // {
      inherit lib machineMetadata machineFlakes;
    };
}
