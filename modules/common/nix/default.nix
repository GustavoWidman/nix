{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    types
    mkIf
    ;

  nixFileName = if config.isDarwin then "nix.custom.conf" else "nix.extra.conf";

  mkValueString =
    v:
    if v == null then
      ""
    else if builtins.isBool v then
      lib.boolToString v
    else if builtins.isInt v then
      builtins.toString v
    else if builtins.isFloat v then
      lib.strings.floatToString v
    # Convert lists of strings like `["foo" "bar"]` into space-separated strings like `foo bar`
    else if builtins.isList v then
      let
        ensureStrings =
          ls:
          lib.forEach ls (
            item:
            if builtins.isString item then
              item
            else
              throw "Expected all list items to be strings but got ${builtins.typeOf item} instead"
          );
      in
      lib.concatStringsSep " " (ensureStrings v)
    else if lib.isDerivation v then
      builtins.toString v
    else if builtins.isPath v then
      builtins.toString v
    else if builtins.isAttrs v then
      builtins.toJSON v
    else if builtins.isString v then
      v
    else if lib.strings.isCoercibleToString v then
      builtins.toString v
    else
      abort "The Nix configuration value ${lib.generators.toPretty { } v} can't be encoded";

  mkKeyValue = k: v: "${lib.escape [ "=" ] k} = ${mkValueString v}";
  mkCustomConfig = attrs: lib.mapAttrsToList mkKeyValue attrs;

  semanticConfType =
    with types;
    let
      confAtom =
        nullOr (oneOf [
          bool
          int
          float
          str
          path
          package
        ])
        // {
          description = "Nix configuration atom (null, Boolean, integer, float, list, derivation, path, attribute set)";
        };
    in
    attrsOf (either confAtom (listOf confAtom));
in
{
  options.nix-settings = lib.mkOption {
    type = types.submodule {
      options = {
        includes = lib.mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of configuration files to include using !include directives";
        };

        extraLines = lib.mkOption {
          type = types.lines;
          default = "";
          description = "Extra lines to add to the Nix configuration file";
        };
      };

      freeformType = semanticConfType;
    };
    default = { };
  };

  config = {
    nix.enable = config.isLinux;

    environment.etc."nix/${nixFileName}".text =
      let
        settingsAttrs = builtins.removeAttrs config.nix-settings [
          "includes"
          "extraLines"
        ];

        includeLines = map (path: "!include ${path}") config.nix-settings.includes;

        extraLinesList = lib.optionals (config.nix-settings.extraLines != "") (
          lib.splitString "\n" config.nix-settings.extraLines
        );
      in
      lib.concatStringsSep "\n" (
        [
          "# Managed by nix-darwin (Manual Shim)"
          ""
        ]
        ++ mkCustomConfig settingsAttrs
        ++ includeLines
        ++ extraLinesList
      );

    nix.extraOptions = mkIf config.isLinux ''
      !include ${nixFileName}
    '';
  };
}
