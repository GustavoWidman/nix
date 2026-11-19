# every machine's ssh host key and the groups secrets are shared with, read
# from hosts/: a machine is a directory with a flake.nix, its key is the first
# line of its host.pub, and its groups follow from its metadata.
#
# `ci` is the deploy workflow's own key, in .github/ci.pub: not a machine, and
# in no group, so it opens only the secrets `recipients` names it for.
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
      metadata = (import ./hosts/${name}/flake.nix).metadata;
    in
    metadata
    // {
      inherit name;
      admin = metadata.admin or false;
      key = firstLine ./hosts/${name}/host.pub;
    };

  # sorted by name, as readDir lists them
  machines = map machine names;
  firstLine = file: head (filter (line: isString line && line != "") (split "\n" (readFile file)));
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
  desktop = keysOf (machine: machine.type == "desktop");
  server = keysOf (machine: machine.type == "dev-server" || machine.type == "server");
  dev = keysOf (machine: machine.type == "desktop" || machine.type == "dev-server");
  all = keysOf (_: true);
  ci = firstLine ./.github/ci.pub;
}
