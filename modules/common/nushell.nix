{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    enabled
    getExe
    mapAttrsToList
    optionalAttrs
    ;

  nushellPath = if config.isDarwin then "Library/Application Support/nushell" else ".config/nushell";
in
{
  environment =
    optionalAttrs config.isLinux {
      sessionVariables.SHELLS = getExe pkgs.nushell;
    }
    // {
      systemPackages = [
        pkgs.carapace
        pkgs.inshellisense
        pkgs.fish
        pkgs.zsh
        pkgs.bash
        pkgs.nushell
        pkgs.zoxide
      ];

      etc."environment" = {
        text =
          config.environment.variables
          |> mapAttrsToList (key: value: "${key}=\"${value}\"")
          |> concatStringsSep "\n";
      };
    };

  home-manager.sharedModules = [
    {
      home.file."${nushellPath}" = {
        source = ./nushell;
        recursive = true;
        force = true;
      };

      programs.nushell = enabled {
        package = pkgs.nushell;
        # the config loads /etc/environment itself, and the loader would start
        # bash on every shell to read the same variables again
        loadSessionVariables = false;

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
