# agenix's rules: every .age file under hosts/ and modules/, encrypted to the
# keys `recipients` in .coeus/bootstrap.nix gives its path. a secret is
# shared by where it lives, so the rules follow the files; see `recipients`.
#
# a new secret needs its file before its rule: create the file, then pipe the
# contents into agenix, which encrypts without decrypting when stdin is not a
# terminal:
#
#   touch hosts/lab/new.age && agenix -e hosts/lab/new.age < plaintext
let
  inherit (builtins)
    attrNames
    concatMap
    listToAttrs
    readDir
    stringLength
    substring
    ;

  inherit (import ./.coeus/bootstrap.nix) recipients;

  isAge = name: stringLength name > 4 && substring (stringLength name - 4) 4 name == ".age";

  # every .age file under `dir`, as a path from the repository root
  secretsUnder =
    dir:
    let
      found = readDir ./${dir};
    in
    concatMap (
      name:
      let
        path = "${dir}/${name}";
      in
      if found.${name} == "directory" then
        secretsUnder path
      else if isAge name then
        [ path ]
      else
        [ ]
    ) (attrNames found);
in
listToAttrs (
  concatMap (
    path:
    let
      publicKeys = recipients path;
    in
    if publicKeys == null then
      [ ]
    else
      [
        {
          name = path;
          value = { inherit publicKeys; };
        }
      ]
  ) (secretsUnder "hosts" ++ secretsUnder "modules")
)
