{
  inputs,
  config,
  self,
  lib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    mapAttrsToList
    filterAttrs
    optionals
    mapAttrs
    mkForce
    isType
    const
    mkIf
    flip
    id
    ;

  registry = inputs |> filterAttrs (const <| isType "flake");

  settings =
    (import <| self + /flake.nix).nixConfig
    |> flip removeAttrs (
      optionals config.isDarwin [
        "use-cgroups"
      ]
    );
in
{
  secrets.github-token-nix-conf = {
    file = ./github-token-nix-conf.age;
    mode = "444";
    owner = "root";
  };

  environment.variables.NIX_PATH = mkForce (
    registry
    |> mapAttrsToList (name: value: "${name}=${value}")
    |> (if config.isDarwin then concatStringsSep ":" else id)
  );

  nix.registry = registry // { default = inputs.nixpkgs; } |> mapAttrs (_: flake: { inherit flake; });

  nix-settings = settings // {
    includes = [ config.secrets.github-token-nix-conf.path ];
  };

  environment.etc."nix/registry.json" = mkIf config.isDarwin {
    text = builtins.toJSON {
      version = 2;
      flakes =
        registry // { default = inputs.nixpkgs; }
        |> mapAttrsToList (
          name: input: {
            from = {
              type = "indirect";
              id = name;
            };
            to = {
              type = "path";
              path = input.outPath;
            };
          }
        );
    };
  };
}
