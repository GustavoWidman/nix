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
    ;
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
        plugins = [
          pkgs.nushellPlugins.gstat
        ];

        package = pkgs.nushell;
      };

      programs.bat = enabled {
        config.theme = "gruvbox-dark";

        config.pager = "less --quit-if-one-screen --RAW-CONTROL-CHARS";
      };
    }
  ];
}
