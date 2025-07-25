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
    id
    isType
    mapAttrs
    mapAttrsToList
    merge
    optionalAttrs
    optionals
    ;

  registryMap = inputs |> filterAttrs (const <| isType "flake");
in
{
  nix.enable = true;
  # nix.package = pkgs.nix;

  environment.systemPackages = with pkgs; [
    deploy-rs
    nh
    nil
    nix-index
    nix-output-monitor
    nixd
    nixfmt-rfc-style
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
        "lazy-trees"
      ]
    );

  nix.optimise.automatic = true;
}
