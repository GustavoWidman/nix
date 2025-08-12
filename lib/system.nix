inputs: self: super:
let
  inherit (self)
    attrValues
    filter
    getAttrFromPath
    hasAttrByPath
    collectNix
    ;

  modulesCommon = collectNix ../modules/common;
  modulesLinux = collectNix ../modules/linux;
  modulesDarwin = collectNix ../modules/darwin;
  modulesDesktop = collectNix ../modules/desktop;
  modulesDev = collectNix ../modules/dev;
  modulesServer = collectNix ../modules/server;

  collectInputs =
    let
      inputs' = attrValues inputs;
    in
    path: inputs' |> filter (hasAttrByPath path) |> map (getAttrFromPath path);

  inputModulesLinux = collectInputs [
    "nixosModules"
    "default"
  ];
  inputModulesDarwin = collectInputs [
    "darwinModules"
    "default"
  ];

  inputOverlays = collectInputs [
    "overlays"
    "default"
  ];
  overlayModule = {
    nixpkgs.overlays = inputOverlays;
  };

  specialArgs = inputs // {
    inherit inputs;

    keys = import ../keys.nix;
    lib = self;
  };
in
{
  linuxDesktopSystem =
    module:
    super.nixosSystem {
      inherit specialArgs;

      modules = [
        module
        overlayModule
      ]
      ++ modulesCommon
      ++ modulesLinux
      ++ modulesDesktop
      ++ modulesDev # desktop is considered a dev environment
      ++ inputModulesLinux;
    };

  linuxDevServerSystem =
    module:
    super.nixosSystem {
      inherit specialArgs;

      modules = [
        module
        overlayModule
      ]
      ++ modulesCommon
      ++ modulesLinux
      ++ modulesDev
      ++ inputModulesLinux;
    };

  linuxServerSystem =
    module:
    super.nixosSystem {
      inherit specialArgs;

      modules = [
        module
        overlayModule
      ]
      ++ modulesCommon
      ++ modulesLinux
      ++ modulesServer
      ++ inputModulesLinux;
    };

  darwinDesktopSystem =
    module:
    super.darwinSystem {
      inherit specialArgs;

      modules = [
        module
        overlayModule
      ]
      ++ modulesCommon
      ++ modulesDarwin
      ++ modulesDesktop
      ++ modulesDev # desktop is considered a dev environment
      ++ inputModulesDarwin;
    };

  darwinServerSystem =
    module:
    super.darwinSystem {
      inherit specialArgs;
      modules = [
        module
        overlayModule
      ]
      ++ modulesCommon
      ++ modulesDarwin
      ++ modulesServer
      ++ inputModulesDarwin;
    };
}
