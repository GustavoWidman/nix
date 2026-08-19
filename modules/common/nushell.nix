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
    ;

  devIncludePackages = with pkgs; [
    krb5.dev
    openssl.dev
    freetds
  ];

  devLibraryPackages = with pkgs; [
    krb5.lib
    openssl.out
    freetds
    llvmPackages.libcxx
  ];

  nushellPath = "${
    if config.isDarwin then "Library/Application Support/nushell" else ".config/nushell"
  }";
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
        NIX_LDFLAGS = concatMapStringsSep " " (pkg: "-L${pkg}/lib") devLibraryPackages;
        NIX_CFLAGS_COMPILE = concatMapStringsSep " " (pkg: "-isystem ${pkg}/include") devIncludePackages;

        LDFLAGS = concatMapStringsSep " " (pkg: "-L${pkg}/lib") devLibraryPackages;
        CPPFLAGS = concatMapStringsSep " " (pkg: "-I${pkg}/include") devIncludePackages;

        LIBRARY_PATH = concatMapStringsSep ":" (pkg: "${pkg}/lib") devLibraryPackages;
      };

      etc."environment" = {
        text =
          config.environment.variables
          |> pkgs.lib.mapAttrsToList (key: value: "${key}=\"${value}\"")
          |> pkgs.lib.concatStringsSep "\n";
      };
    };

  home-manager.sharedModules = [
    (mkIf config.isDarwin {
      home.file."${nushellPath}/autoload" = {
        source = ../macos/nushell;
        recursive = true;
        force = true;
      };
    })
    {
      home.file."${nushellPath}" = {
        source = ./nushell;
        recursive = true;
        force = true;
      };

      programs.nushell = enabled {
        package = pkgs.nushell;

        configFile.text = ''
          open /etc/environment | from toml | load-env
          source ($nu.default-config-dir | path join main.nu)
        '';
      };

      programs.bat = enabled {
        config.theme = "gruvbox-dark";

        config.pager = "less --quit-if-one-screen --RAW-CONTROL-CHARS";
      };
    }
  ];
}
