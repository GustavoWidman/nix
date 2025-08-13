{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    getExe
    mkIf
    optionalAttrs
    enabled
    concatMapStringsSep
    filter
    ;

  devPackages = filter (pkg: builtins.pathExists "${pkg}/lib") config.environment.systemPackages;

  # Get all packages with include directories
  devPackagesWithHeaders = filter (
    pkg: builtins.pathExists "${pkg}/include"
  ) config.environment.systemPackages;
in
{
  environment =
    optionalAttrs config.isLinux {
      sessionVariables.SHELLS = getExe pkgs.nushell;
    }
    // {
      shells = mkIf config.isDarwin [ pkgs.nushell ];

      systemPackages = with pkgs; [
        carapace
        inshellisense
        fish
        zsh
        bash
        nushell
        zoxide
      ];

      variables = mkIf config.isDev {
        NIX_LDFLAGS = concatMapStringsSep " " (pkg: "-L${pkg}/lib") devPackages;
        NIX_CFLAGS_COMPILE = concatMapStringsSep " " (
          pkg: "-isystem ${pkg}/include"
        ) devPackagesWithHeaders;

        LDFLAGS = concatMapStringsSep " " (pkg: "-L${pkg}/lib") devPackages;
        CPPFLAGS = concatMapStringsSep " " (pkg: "-I${pkg}/include") devPackagesWithHeaders;

        LIBRARY_PATH = concatMapStringsSep ":" (pkg: "${pkg}/lib") devPackages;
        # PKG_CONFIG_PATH = concatMapStringsSep ":" (pkg: "${pkg}/lib/pkgconfig") (
        #   filter (pkg: builtins.pathExists "${pkg}/lib/pkgconfig") devPackages
        # );
      };

      etc."environment" = {
        text =
          config.environment.variables
          |> pkgs.lib.mapAttrsToList (key: value: "${key}=\"${value}\"")
          |> pkgs.lib.concatStringsSep "\n";
      };
    };

  home-manager.sharedModules = [
    {
      home.file."${
        if config.isDarwin then "Library/Application Support/nushell" else ".config/nushell"
      }" =
        {
          source = ./nushell;
          recursive = true;
          force = true;
        };

      programs.nushell = enabled {
        package = pkgs.nushell;

        configFile.text = ''
          source ($nu.default-config-dir | path join _config.nu)
        '';

        envFile.text = ''
          open /etc/environment | from toml | load-env
          source ($nu.default-config-dir | path join _env.nu)
        '';

        # sometimes, even my own genius scares me
        # environmentVariables = config.environment.variables;
      };

      programs.bat = enabled {
        config.theme = "gruvbox-dark";

        config.pager = "less --quit-if-one-screen --RAW-CONTROL-CHARS";
      };
    }
  ];
}
