_: self: _:
let
  inherit (self)
    concatMapAttrsStringSep
    fleet
    mapAttrs
    optional
    ;
in
{
  # the coeus CLI's inventory: `@all`, `@nixos`, `@darwin`, `@<type>` and `@canary`
  coeusHosts =
    fleet
    |> mapAttrs (
      name: machine: {
        tags = [
          machine.class
          machine.type
        ]
        ++ optional (name == "lab") "canary";
      }
    );

  # the same inventory as a `coeus.toml` for machines outside the fleet, such
  # as CI, which pass the key in `COEUS_KEY`. JSON strings and arrays are TOML.
  coeusClientConfig =
    self.coeusHosts
    |> concatMapAttrsStringSep "\n" (
      name: host: ''
        [settings.hosts.${builtins.toJSON name}]
        tags = ${builtins.toJSON host.tags}
      ''
    );
}
