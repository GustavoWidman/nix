_: self: _:
let
  inherit (self)
    attrNames
    concatMapAttrsStringSep
    filterAttrs
    fleet
    mapAttrs
    optional
    ;
in
{
  # whether a machine serves the dashboard: the servers and dev servers, the
  # machines that open modules/server's secrets
  servesCoeusWeb = machine: machine.type != "desktop";

  # every machine that serves the dashboard, by name
  coeusWebHosts = fleet |> filterAttrs (_: self.servesCoeusWeb) |> attrNames;

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
