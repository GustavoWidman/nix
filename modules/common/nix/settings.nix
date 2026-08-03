{
  inputs,
  config,
  self,
  lib,
  pkgs,
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

  determinateNix = inputs.determinate.inputs.nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
  determinateNixRuntime = pkgs.symlinkJoin {
    pname = "determinate-nix";
    version = determinateNix.version;
    name = "determinate-nix-${determinateNix.version}";
    paths = [ (lib.getOutput "out" determinateNix) ];
  };
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

  # Determinate's cache publishes the runtime output, not Nix's auxiliary outputs.
  nix.package = mkIf config.isLinux (mkForce determinateNixRuntime);

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

  services.nh-clean.enable = true;
}
