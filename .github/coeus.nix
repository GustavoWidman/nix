# the fleet's coeus inventory, read from `hosts/` with nothing but builtins, so
# CI writes it without fetching nixpkgs. the same as `.#coeus.clientConfig`.
let
  # the few nixpkgs lib functions `lib/fleet.nix` and `lib/coeus.nix` use
  helpers = {
    const = value: _: value;
    optional = condition: value: if condition then [ value ] else [ ];
    filterAttrs =
      keep: set:
      builtins.listToAttrs (
        builtins.concatMap (
          name:
          if keep name set.${name} then
            [
              {
                inherit name;
                value = set.${name};
              }
            ]
          else
            [ ]
        ) (builtins.attrNames set)
      );
    concatMapAttrsStringSep =
      separator: render: set:
      builtins.concatStringsSep separator (builtins.attrValues (builtins.mapAttrs render set));
  };

  lib = builtins // helpers // fleet // coeus;
  fleet = import ../lib/fleet.nix null lib null;
  coeus = import ../lib/coeus.nix null lib null;
in
lib.coeusClientConfig
