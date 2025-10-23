_: self: super:
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
  modulesDarwin = collectNix ../modules/macos;
  modulesDesktop = collectNix ../modules/desktop;
  modulesDev = collectNix ../modules/dev;
  modulesServer = collectNix ../modules/server;

  collectInputsFrom =
    inputSet:
    let
      inputs' = attrValues inputSet;
    in
    path: inputs' |> filter (hasAttrByPath path) |> map (getAttrFromPath path);
in
{
  linuxDesktopSystem =
    inputs: module:
    let
      inputModulesLinux = collectInputsFrom inputs [
        "nixosModules"
        "default"
      ];
      inputOverlays = collectInputsFrom inputs [
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
    inputs: module:
    let
      inputModulesLinux = collectInputsFrom inputs [
        "nixosModules"
        "default"
      ];
      inputOverlays = collectInputsFrom inputs [
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
    inputs: module:
    let
      inputModulesLinux = collectInputsFrom inputs [
        "nixosModules"
        "default"
      ];
      inputOverlays = collectInputsFrom inputs [
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
    inputs: module:
    let
      inputModulesDarwin = collectInputsFrom inputs [
        "darwinModules"
        "default"
      ];
      inputOverlays = collectInputsFrom inputs [
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
    inputs: module:
    let
      inputModulesDarwin = collectInputsFrom inputs [
        "darwinModules"
        "default"
      ];
      inputOverlays = collectInputsFrom inputs [
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
