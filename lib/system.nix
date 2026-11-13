_: self: super:
let
  inherit (self)
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

  # every machine imports these inputs' default modules; a
  # machine that runs another input's service imports that module itself
  fleetInputs = [
    "agenix"
    "coeus"
    "determinate"
    "home-manager"
    "kache"
    "nix-homebrew"
    "rift"
  ];

  # the fleet inputs whose overlays machines read: pkgs.agenix and pkgs.rift
  fleetOverlays = [
    "agenix"
    "rift"
  ];

  overlaysFrom =
    inputSet:
    fleetOverlays |> filter (name: inputSet ? ${name}) |> map (name: inputSet.${name}.overlays.default);

  collectInputsFrom =
    inputSet:
    let
      inputs' = fleetInputs |> filter (name: inputSet ? ${name}) |> map (name: inputSet.${name});
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
      inputOverlays = overlaysFrom inputs;
      overlayModule = {
        nixpkgs.overlays = inputOverlays;
      };

      specialArgs = inputs // {
        inherit inputs;
        isDarwin = false;
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
      inputOverlays = overlaysFrom inputs;
      overlayModule = {
        nixpkgs.overlays = inputOverlays;
      };

      specialArgs = inputs // {
        inherit inputs;
        isDarwin = false;
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
      ++ modulesServer
      ++ inputModulesLinux;
    };

  linuxServerSystem =
    inputs: module:
    let
      inputModulesLinux = collectInputsFrom inputs [
        "nixosModules"
        "default"
      ];
      inputOverlays = overlaysFrom inputs;
      overlayModule = {
        nixpkgs.overlays = inputOverlays;
      };

      specialArgs = inputs // {
        inherit inputs;
        isDarwin = false;
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
      inputOverlays = overlaysFrom inputs;
      overlayModule = {
        nixpkgs.overlays = inputOverlays;
      };

      specialArgs = inputs // {
        inherit inputs;
        isDarwin = true;
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

  darwinDevServerSystem =
    inputs: module:
    let
      inputModulesDarwin = collectInputsFrom inputs [
        "darwinModules"
        "default"
      ];
      inputOverlays = overlaysFrom inputs;
      overlayModule = {
        nixpkgs.overlays = inputOverlays;
      };

      specialArgs = inputs // {
        inherit inputs;
        isDarwin = true;
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
      ++ modulesDev
      ++ modulesServer
      ++ inputModulesDarwin;
    };

  darwinServerSystem =
    inputs: module:
    let
      inputModulesDarwin = collectInputsFrom inputs [
        "darwinModules"
        "default"
      ];
      inputOverlays = overlaysFrom inputs;
      overlayModule = {
        nixpkgs.overlays = inputOverlays;
      };

      specialArgs = inputs // {
        inherit inputs;
        isDarwin = true;
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
