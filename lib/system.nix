_: self: super:
let
  inherit (self)
    collectNix
    concatMap
    filter
    getAttrFromPath
    hasAttrByPath
    ;

  # a machine that runs another input's service imports that module itself
  fleetInputs = [
    "agenix"
    "coeus"
    "determinate"
    "home-manager"
    "kache"
    "nix-homebrew"
    "rift"
  ];

  fleetOverlays = [
    "agenix"
    "rift"
  ];

  # directory order is import order, which decides how list options merge
  classes = {
    nixos = {
      build = super.nixosSystem;
      inputModules = "nixosModules";
      directories = {
        desktop = [
          "linux"
          "desktop"
          "dev"
        ];
        dev-server = [
          "linux"
          "dev"
          "server"
        ];
        server = [
          "linux"
          "server"
        ];
      };
    };

    darwin = {
      build = super.darwinSystem;
      inputModules = "darwinModules";
      directories = {
        desktop = [
          "macos"
          "desktop"
          "dev"
        ];
        dev-server = [
          "macos"
          "dev"
        ];
        server = [ "macos" ];
      };
    };
  };
in
{
  # the system of a machine of the fleet, from its metadata and its module
  mkSystem =
    inputs: metadata: module:
    let
      class = classes.${metadata.class};
      inputModules = [
        class.inputModules
        "default"
      ];
    in
    class.build {
      specialArgs = inputs // {
        inherit inputs;
        isDarwin = metadata.class == "darwin";
        keys = import ../keys.nix;
        lib = self;
      };

      modules = [
        module
        { nixpkgs.overlays = map (input: inputs.${input}.overlays.default) fleetOverlays; }
      ]
      ++ concatMap (directory: collectNix ../modules/${directory}) (
        [ "common" ] ++ class.directories.${metadata.type}
      )
      ++ (
        fleetInputs
        |> map (input: inputs.${input})
        |> filter (hasAttrByPath inputModules)
        |> map (getAttrFromPath inputModules)
      );
    };
}
