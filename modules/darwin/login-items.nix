{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.system.login-items;

  loginItemSubmodule = types.submodule {
    options = {
      package = mkOption {
        type = types.package;
        description = "The package to run at login";
      };

      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Custom command to run (overrides auto-detection).
          If null, will auto-detect the executable path.
        '';
      };

      script = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = ''
          Custom script to run instead of a direct command.
          If set, this takes precedence over command.
        '';
      };

      serviceConfig = mkOption {
        type = types.attrs;
        default = { };
        description = "Additional launchd service configuration";
      };

      keepAlive = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to keep the process alive (restart if it crashes).
          Set to false for apps that should only run once at login.
        '';
      };

      guiApp = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether this is a GUI application that needs to run in interactive mode.
          Set to false for command-line tools or background services.
        '';
      };

      enableLogging = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to enable logging for this login item to /tmp/*.log files.
          Useful for debugging startup issues.
        '';
      };
    };
  };

  autoDetectCommand =
    pkg:
    let
      pkgName = pkg.pname or pkg.name;
      macosAppPath = "${pkg}/Applications/${pkgName}.app/Contents/MacOS/${pkgName}";
      binPath = "${pkg}/bin/${pkgName}";
    in
    if pathExists "${pkg}/Applications/${pkgName}.app" then
      macosAppPath
    else if pathExists binPath then
      binPath
    else
      throw ''
        Could not auto-detect executable for package '${pkgName}' in login-items.

        Checked paths:
          - ${macosAppPath}
          - ${binPath}

        Package location: ${pkg}

        Solutions:
          1. Find the correct executable path:
             $ ls -la ${pkg}/
             $ find ${pkg} -name "${pkgName}" -o -name "*.app"

          2. Then specify the correct command explicitly:
             {
               package = pkgs.${pkgName};
               command = "''${pkgs.${pkgName}}/correct/path/to/executable";
             }

          3. For .app bundles, usually:
             command = "''${pkgs.${pkgName}}/Applications/AppName.app/Contents/MacOS/AppName";
      '';

  normalizeLoginItem =
    item:
    let
      # If it's just a package, wrap it in default submodule values
      normalized =
        if types.package.check item then
          {
            package = item;
            command = null;
            script = null;
            serviceConfig = { };
            keepAlive = true;
            guiApp = true;
            enableLogging = false;
          }
        else
          item;

      pkgName = normalized.package.pname or normalized.package.name;

      # Determine the command to run
      finalCommand =
        if normalized.script != null then
          null # script takes precedence
        else if normalized.command != null then
          normalized.command
        else
          autoDetectCommand normalized.package;

    in
    {
      name = pkgName;
      value = {
        command = mkIf (finalCommand != null) finalCommand;
        script = mkIf (normalized.script != null) normalized.script;

        serviceConfig = {
          RunAtLoad = true;
          KeepAlive = normalized.keepAlive;
          ProcessType = if normalized.guiApp then "Interactive" else "Standard";
        }
        // optionalAttrs normalized.enableLogging {
          StandardOutPath = "/tmp/${pkgName}.out.log";
          StandardErrorPath = "/tmp/${pkgName}.err.log";
        }
        // normalized.serviceConfig; # Allow overriding any of the above
      };
    };

in
{
  options.system.login-items = mkOption {
    type = types.listOf (types.either types.package loginItemSubmodule);
    default = [ ];
    example = literalExpression ''
      [
        pkgs.stats                    # Simple package
        pkgs.rectangle               # Another simple package
        {
          package = pkgs.bash;
          script = '''
            echo "System started at $(date)" >> /tmp/startup.log
            open -a "Stats"
            sleep 2
            open -a "Rectangle"
          ''';
          enableLogging = true;
          keepAlive = false;
        }
        {
          package = pkgs.stats;
          command = "''${pkgs.stats}/Applications/Stats.app/Contents/MacOS/Stats --background";
          serviceConfig = {
            LSUIElement = true;        # Hide from dock
          };
        }
      ]
    '';
    description = ''
      List of packages or configurations to automatically start at login.

      Each item can be either:
        - A package directly (e.g., pkgs.stats)
        - A configuration object with package and additional options

      This creates launchd user agents for each item.
    '';
  };

  config = mkIf (cfg != [ ]) {
    launchd.user.agents = listToAttrs (map normalizeLoginItem cfg);
  };
}
