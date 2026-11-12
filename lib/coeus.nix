_: self: _:
let
  inherit (self) fleet mapAttrs optional;
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
}
