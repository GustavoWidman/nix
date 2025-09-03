{
  self,
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    const
    disabled
    filterAttrs
    flip
    length
    id
    isType
    mapAttrs
    mapAttrsToList
    merge
    optionalAttrs
    optionals
    attrsToList
    filter
    ;

  registryMap = inputs |> filterAttrs (const <| isType "flake");
in
{
  nix.enable = true;
  nix.package = pkgs.nix;

  nix.distributedBuilds = true;
  nix.buildMachines =
    self.machineMetadata
    |> attrsToList
    |> filter (
      { name, value }: (name != config.networking.hostName) && (length value.build-architectures > 0)
    )
    |> map (
      { name, value }:
      {
        hostName = name;
        maxJobs = 20;
        protocol = "ssh-ng";
        sshUser = "build";
        sshKey = config.secrets.ssh-misc-build.path;
        supportedFeatures = [
          "benchmark"
          "big-parallel"
          "kvm"
          "nixos-test"
        ];
        systems = value.build-architectures;
      }
    );

  environment.systemPackages =
    with pkgs;
    [
      deploy-rs
      nh
      nix-index
      nix-output-monitor
      nixfmt-rfc-style
    ]
    ++ lib.lists.optionals config.isDev [
      (nil.override {
        nix = inputs.nixpkgs.legacyPackages.${system}.nix;
      })
      nixd
    ];

  nix.channel = disabled;

  nix.gc =
    merge {
      automatic = true;
      options = "--delete-older-than 3d";
    }
    <| optionalAttrs config.isLinux {
      dates = "weekly";
      persistent = true;
    };

  nix.nixPath =
    registryMap
    |> mapAttrsToList (name: value: "${name}=${value}")
    |> (if config.isDarwin then concatStringsSep ":" else id);

  nix.registry =
    registryMap // { default = inputs.nixpkgs; } |> mapAttrs (_: flake: { inherit flake; });

  nix.settings =
    (import <| self + /flake.nix).nixConfig
    |> flip removeAttrs (
      optionals config.isDarwin [
        "use-cgroups"
      ]
    );

  nix.optimise.automatic = true;
}
