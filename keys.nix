# every machine's ssh host key and the groups secrets are shared with, read
# from hosts/: a machine is a directory with a flake.nix, its key is the first
# line of its host.pub, and its groups follow from its metadata.
#
# builtins only: agenix's CLI evaluates this through secrets.nix with plain
# nix, and coeus through .coeus/bootstrap.nix, neither with nixpkgs.
let
  inherit (builtins)
    attrNames
    filter
    head
    isString
    listToAttrs
    map
    pathExists
    readDir
    readFile
    split
    ;

  entries = readDir ./hosts;
  names = filter (name: entries.${name} == "directory" && pathExists ./hosts/${name}/flake.nix) (
    attrNames entries
  );

  machine =
    name:
    let
      metadata = (import ./hosts/${name}/flake.nix { }).outputs.metadata;
    in
    metadata
    // {
      inherit name;
      admin = metadata.admin or false;
      key = head (
        filter (line: isString line && line != "") (split "\n" (readFile ./hosts/${name}/host.pub))
      );
    };

  # sorted by name, as readDir lists them
  machines = map machine names;
  keysOf = keep: map (machine: machine.key) (filter keep machines);

  keys = listToAttrs (
    map (machine: {
      inherit (machine) name;
      value = machine.key;
    }) machines
  );
in
keys
// {
  admins = keysOf (machine: machine.admin);
  linux = keysOf (machine: machine.class == "nixos");
  darwin = keysOf (machine: machine.class == "darwin");
  server = keysOf (machine: machine.class == "nixos" && machine.type != "desktop");
  dev = keysOf (machine: machine.type == "desktop");
  all = keysOf (_: true);
}
