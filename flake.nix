{
  description = "r3dlust's Nix Config Collection";

  nixConfig = {
    extra-substituters = [
      # "https://cache.r3dlust.com/"
      "https://cache.garnix.io/"
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://install.determinate.systems"
      # "https://cache.flakehub.com"
    ];

    extra-trusted-public-keys = [
      # "cache.r3dlust.com:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      # "cache.flakehub.com-1:t6986ugxCA+d/ZF6IzeE2XmLZNMCfHdPIHPPkNF8cTQ="
    ];

    experimental-features = [
      "cgroups"
      "flakes"
      "nix-command"
      "pipe-operators"
    ];

    builders-use-substitutes = true;
    keep-outputs = true;
    flake-registry = "";
    http-connections = 50;
    max-substitution-jobs = 50;
    lazy-trees = true;
    show-trace = true;
    trusted-users = [
      "root"
      "@wheel"
      "@admin"
    ];
    use-cgroups = true;
    warn-dirty = false;
  };

  inputs = {
    self.submodules = true;

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
    nh.url = "github:nix-community/nh";

    dailybot = {
      url = ./.inputs/dailybot;

      inputs.nixpkgs.follows = "nixpkgs";
    };
    naersk.url = "github:nix-community/naersk";
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

      lib' = nixpkgs.lib.extend (const <| const <| nix-darwin.lib);
      lib = lib'.extend <| import ./lib inputs;

      hostsByType =
        readDir ./hosts
        |> mapAttrs (name: const <| import ./hosts/${name} lib)
        |> attrsToList
        |> groupBy (
          { value, ... }:
          if value ? class && value.class == "nixos" then "nixosConfigurations" else "darwinConfigurations"
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
      inherit lib;

      # herculesCI = { ... }: {
      #   ciSystems = [ "aarch64-linux" "x86_64-linux" ];
      # };
    };
}
