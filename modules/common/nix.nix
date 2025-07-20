{
  self,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    attrValues
    optionals
    ;
in
{
  # allow nix-darwin with Determinate
  nix.enable = false;

  environment.systemPackages = attrValues {
    inherit (pkgs)
      nh
      nix-index
      nix-output-monitor
      nixd
      nixfmt-rfc-style
      ;
  };

  environment.etc."nix/registry.json".text =
    let
      flakeInputs = (import <| self + /flake.nix).inputs;

      registryEntries = lib.mapAttrs (name: input: {
        from = {
          id = name;
          type = "indirect";
        };
        to = {
          type = "github";
          owner = input.owner or (throw "Input ${name} missing owner");
          repo = input.repo or (throw "Input ${name} missing repo");
          ref = input.ref or input.branch or "main";
        } // (lib.optionalAttrs (input ? rev) { inherit (input) rev; });
      }) flakeInputs;

      registry = {
        flakes = registryEntries;
        version = 2;
      };
    in
    builtins.toJSON registry;

  environment.etc."nix/nix.custom.conf".text =
    let
      nixConfig = (import <| self + /flake.nix).nixConfig;
      filteredConfig = removeAttrs nixConfig (optionals config.isDarwin [ "use-cgroups" ]);

      mkNixValue =
        value:
        if lib.isList value then
          lib.concatStringsSep " " value
        else if lib.isBool value then
          if value then "true" else "false"
        else
          toString value;
    in
    lib.generators.toKeyValue {
      mkKeyValue = key: value: "${key} = ${mkNixValue value}";
    } filteredConfig;
}
