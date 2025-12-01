{
  determinate,
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
    filterAttrs
    flip
    mkIf
    length
    id
    isType
    isList
    isBool
    mapAttrs
    mapAttrsToList
    mergeAttrs
    optionals
    attrsToList
    filter
    mkForce
    ;

  registryMap = inputs |> filterAttrs (const <| isType "flake");

  nixSettings = (
    ((import (self + /flake.nix)).nixConfig or { })
    |> flip removeAttrs (optionals config.isDarwin [ "use-cgroups" ])
    |> mergeAttrs {
      "extra-experimental-features" = [
        "nix-command"
        "flakes"
      ];
      "builders-use-substitutes" = true;
    }
    |> mapAttrs (
      name: value:
      if isList value then
        concatStringsSep " " value
      else if isBool value then
        (if value then "true" else "false")
      else
        toString value
    )
    |> filterAttrs (name: value: value != "")
    |> mapAttrsToList (name: value: "${name} = ${value}")
    |> concatStringsSep "\n"
  );

  machinesList =
    self.machineMetadata
    |> attrsToList
    |> filter (
      { name, value }: (name != config.networking.hostName) && (length value.build-architectures > 0)
    )
    |> map (
      { name, value }:
      let
        systems = concatStringsSep "," value.build-architectures;
        key = config.secrets.ssh-misc-build.path;
        features = concatStringsSep "," [
          "benchmark"
          "big-parallel"
          "kvm"
          "nixos-test"
        ];
      in
      "ssh-ng://build@${name} ${systems} ${key} 20 1 ${features} - -"
    );

  nixPathStr =
    registryMap
    |> mapAttrsToList (name: value: "${name}=${value}")
    |> (if config.isDarwin then concatStringsSep ":" else id);

  nixFileName = if config.isDarwin then "nix.custom.conf" else "nix.extra.conf";
in
{
  nix.enable = config.isLinux;

  environment.variables.NIX_PATH = mkForce nixPathStr;

  secrets.github-token-nix-conf = {
    file = ./github-token-nix-conf.age;
    mode = "444";
    owner = "root";
  };

  environment.etc.${nixFileName}.text = ''
    # Managed by nix-darwin (Manual Shim)

    ${nixSettings}

    !include ${config.secrets.github-token-nix-conf.path}

    auto-optimise-store = true
  '';

  environment.etc."nix/machines".text = concatStringsSep "\n" machinesList;

  nix.registry =
    registryMap // { default = inputs.nixpkgs; } |> mapAttrs (_: flake: { inherit flake; });

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
      nixd
    ];

  nix.extraOptions = mkIf config.isLinux ''
    !include ${nixFileName}
  '';
}
