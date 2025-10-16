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

  nushell = final: prev: {
    nushell = prev.nushell.override (
      let
        rp = prev.rustPlatform;
      in
      {
        rustPlatform = rp // {
          buildRustPackage =
            args:
            rp.buildRustPackage (
              args
              // rec {
                version = "0.108.0";
                src = prev.fetchFromGitHub {
                  owner = "nushell";
                  repo = "nushell";
                  tag = version;
                  hash = "sha256-8OMTscMObV+IOSgOoTSzJvZTz6q/l2AjrOb9y3p2tZY=";
                };
                cargoHash = "sha256-M2wkhhaS3bVhwaa3O0CUK5hL757qFObr7EDtBFXXwxg=";
              }
            );
        };
      }
    );
  };

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
        nixpkgs.overlays = inputOverlays ++ [ nushell ];
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
        nixpkgs.overlays = inputOverlays ++ [ nushell ];
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
        nixpkgs.overlays = inputOverlays ++ [ nushell ];
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
        nixpkgs.overlays = inputOverlays ++ [ nushell ];
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
        nixpkgs.overlays = inputOverlays ++ [ nushell ];
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
