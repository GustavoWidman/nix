{
  inputs,
  config,
  self,
  lib,
  pkgs,
  isDarwin,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    mapAttrsToList
    filterAttrs
    mapAttrs
    optionalAttrs
    remove
    mkForce
    mkAfter
    mkMerge
    isType
    const
    id
    ;

  # the config's own source would make every commit a new generation on every
  # machine, even one that touches a single host, and nothing looks it up
  flakes = removeAttrs inputs [ "self" ] |> filterAttrs (const <| isType "flake");
  registry = flakes // { default = inputs.nixpkgs; } |> mapAttrs (_: flake: { inherit flake; });

  extra-platforms = remove config.metadata.architecture config.metadata.build-architectures;
  # extra-platforms = [ ] turns off nix's default platforms (i686-linux,
  # x86_64-v*), so it is set only when the machine builds for more
  settings =
    (import <| self + /flake.nix).nixConfig
    // optionalAttrs (extra-platforms != [ ]) { inherit extra-platforms; };
  includeGithubToken = "!include ${config.secrets.github-token-nix-conf.path}";

  determinateNix = inputs.determinate.inputs.nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
  determinateNixRuntime = pkgs.symlinkJoin {
    pname = "determinate-nix";
    version = determinateNix.version;
    name = "determinate-nix-${determinateNix.version}";
    paths = [ (lib.getOutput "out" determinateNix) ];
  };
in
mkMerge [
  {
    secrets.github-token-nix-conf = {
      file = ./github-token-nix-conf.age;
      mode = "444";
      owner = "root";
    };

    environment.variables.NIX_PATH = mkForce (
      flakes
      |> mapAttrsToList (name: value: "${name}=${value}")
      |> (if isDarwin then concatStringsSep ":" else id)
    );
  }

  (
    if isDarwin then
      {
        determinateNix = {
          inherit registry;
          customSettings = removeAttrs settings [ "use-cgroups" ] // {
            # Determinate points the global registry at the system one whenever
            # it writes a registry; empty keeps it off, as on NixOS
            flake-registry = mkForce settings.flake-registry;
          };
        };

        environment.etc."nix/nix.custom.conf".text = mkAfter includeGithubToken;
      }
    else
      {
        nix = {
          inherit registry settings;
          extraOptions = includeGithubToken;
          # Determinate's cache publishes the runtime output, not Nix's auxiliary outputs.
          package = mkForce determinateNixRuntime;
        };
      }
  )
]
