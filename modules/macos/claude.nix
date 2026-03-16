{
  pkgs,
  ...
}:
let
  json = pkgs.formats.json { };

  notifier = pkgs.writeShellScript "claude-notifier" ''
    #!/usr/bin/env bash

    DIR=$(pwd | xargs basename)

    case $2 in
        "ok") SOUND="Purr" ;;
        "error") SOUND="Funk" ;;
        *) SOUND="Pop" ;;
    esac

    osascript -e "display notification \"$1\" with title \"Claude Code ($DIR)\" sound name \"$SOUND\""
  '';
in
{
  home-manager.sharedModules = [
    {
      home.file.".claude/settings.json".source = json.generate "claude-code-settings.json" {
        "$schema" = "https://json.schemastore.org/claude-code-settings.json";
        attribution = {
          commit = "";
          pr = "";
        };
        includeCoAuthoredBy = false;
        permissions = {
          defaultMode = "bypassPermissions";
          deny = [
            "Bash(*git push*)"
            "Bash(*jj push*)"
          ];
        };
        enabledPlugins = {
          "frontend-design@claude-plugins-official" = true;
          "superpowers@claude-plugins-official" = true;
          "typescript-lsp@claude-plugins-official" = true;
          "pyright-lsp@claude-plugins-official" = true;
          "gopls-lsp@claude-plugins-official" = true;
          "rust-analyzer-lsp@claude-plugins-official" = true;
          "clangd-lsp@claude-plugins-official" = true;
          "skill-creator@claude-plugins-official" = true;
        };
        skipDangerousModePermissionPrompt = true;
        effortLevel = "medium";
        hooks = {
          Stop = [
            {
              matcher = "";
              hooks = [
                {
                  type = "command";
                  command = "${notifier} 'Task completed successfully' ok";
                }
              ];
            }
          ];
          Notification = [
            {
              matcher = "";
              hooks = [
                {
                  type = "command";
                  command = "${notifier} 'Needs your input' error";
                }
              ];
            }
          ];
        };
      };
    }
  ];
}
