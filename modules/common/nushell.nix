{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    attrValues
    getExe
    mkIf
    optionalAttrs
    ;
in
{
  environment =
    optionalAttrs config.isLinux {
      sessionVariables.SHELLS = getExe pkgs.nushell;
    }
    // {
      shells = mkIf config.isDarwin [ pkgs.nushell ];

      systemPackages = attrValues {
        inherit (pkgs)
          carapace
          inshellisense
          fish
          zsh
          bash
          nushell
          zoxide
          ;
      };
    };

  home-manager.sharedModules = [
    (
      homeArgs:
      let
        # config' = homeArgs.config;
      in
      {
        home.file."${
          if config.isDarwin then "Library/Application Support/nushell" else ".config/nushell"
        }" =
          {
            source = ./nushell;
            recursive = true;
            force = true;
          };
      }
    )
  ];
}
