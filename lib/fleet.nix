_: self: _:
let
  inherit (self) const filterAttrs mapAttrs;
in
{
  # every machine's `metadata`, keyed by its directory under `hosts/`
  fleet =
    builtins.readDir ../hosts
    |> filterAttrs (_: type: type == "directory")
    |> mapAttrs (name: const (import ../hosts/${name}/flake.nix { }).outputs.metadata);
}
