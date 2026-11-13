{
  description = "r3dlust's Nix Config Collection";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://265866.cachix.org"
      "https://install.determinate.systems"
      "https://cache.r3dlust.com"
    ];

    extra-trusted-public-keys = [
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.r3dlust.com-1:Wdkf9mes2ued0P7C7CL3Jax1b4KPuJwQpM3h4G/Z+yI="
      "265866.cachix.org-1:KeHQ4qkDufShpWve8YcDhFsmWLEzMDrDoinVpahhBEc="
    ];

    experimental-features = [
      "cgroups"
      "flakes"
      "nix-command"
      "pipe-operators"
    ];

    builders-use-substitutes = true;
    # a cache that keeps failing, as cache.r3dlust.com does while lab is off,
    # is skipped for a minute after its retries instead of costing them again
    # for every path, and a download that stops moving fails within seconds
    fallback = true;
    stalled-download-timeout = 20;
    keep-outputs = true;
    flake-registry = "";
    http-connections = 50;
    max-substitution-jobs = 50;
    eval-cores = 0;
    show-trace = true;
    trusted-users = [
      "root"
      "@build"
      "@wheel"
      "@admin"
    ];
    use-cgroups = true;
    warn-dirty = false;
  };

  inputs = {
    self.submodules = true;

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

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
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver/main";

      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix.url = "github:nix-community/fenix";
    crane.url = "github:ipetkov/crane";
    rift = {
      # url = "github:acsandmann/rift";
      url = "github:gustavowidman/rift/feat/nix-compat";
    };

    arion = {
      url = "github:hercules-ci/arion";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    oxi = {
      url = "github:c0h1b4/oxi";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.fenix.follows = "fenix";
      inputs.crane.follows = "crane";
      inputs.bun2nix.follows = "portfolio/bun2nix";
    };

    copyparty.url = "github:9001/copyparty";
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # a release tag with taproot's own nixpkgs, which 265866.cachix.org builds
    taproot.url = "github:265866/taproot/taproot-v0.7.0";
    coeus.url = "github:GustavoWidman/coeus";
    kache.url = "github:kunobi-ninja/kache";

    zed.url = "github:GustavoWidman/zed-autobuild";
    kemono-pinger.url = "github:GustavoWidman/kemono-pinger";
    portfolio.url = "github:GustavoWidman/portfolio";
    heimdall.url = "github:GustavoWidman/heimdall";
    # claude-who.url = "git+ssh://git@github.com/GustavoWidman/claude-who";
    rocky-bot.url = "git+ssh://git@github.com/GustavoWidman/rocky-bot";
    thoth = {
      url = "git+ssh://git@github.com/GustavoWidman/thoth";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niks3 = {
      url = "github:Mic92/niks3";
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

      machineMetadata = lib.fleet;

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

      coeus.clientConfig = lib.coeusClientConfig;

      # vm tests of this repository's modules
      checks = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
        tailscale-certificate = nixpkgs.legacyPackages.${system}.testers.runNixOSTest ./tests/tailscale-certificate.nix;
      });
    };
}
