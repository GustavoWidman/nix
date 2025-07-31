{ lib, config, ... }:
let
  inherit (lib)
    enabled
    merge
    mkIf
    ;
in
merge
<| mkIf config.isDesktop {
  home-manager.sharedModules = [
    {
      programs.zed-editor = enabled {
        userSettings = {
          icon_theme = "Material Icon Theme";
          autosave = "on_focus_change";
          theme = "Base16 Gruvbox dark, medium";
          buffer_font_family = "Fira Code";
          terminal.button = false;
          show_whitespaces = "selection";
          read_ssh_config = true;
          debugger.button = false;
          close_on_file_delete = true;
          soft_wrap = "bounded";
          show_wrap_guides = false;
          telemetry = {
            metrics = false;
            diagnostics = false;
          };
          tab_bar.show_nav_history_buttons = false;
          minimap = {
            show = "always";
            max_width_columns = 120;
          };
          toolbar = {
            breadcrumbs = false;
            agent_review = false;
            selections_menu = false;
            code_actions = false;
            quick_actions = false;
          };
          title_bar = {
            show_branch_icon = true;
            show_onboarding_banner = false;
            show_user_picture = false;
          };
          agent.enabled = false;
          languages."Nix".formatter."external" = {
            command = "nixfmt";
            arguments = [ "-q" ];
          };
          diagnostics.inline.enabled = true;
          features.edit_prediction_provider = "copilot";
        };
        userKeymaps = [
          {
            context = "Editor";
            bindings = {
              alt-space = "editor::ShowCompletions";
            };
          }
          {
            context = "Pane";
            bindings = {
              cmd-1 = [
                "pane::ActivateItem"
                0
              ];
              cmd-2 = [
                "pane::ActivateItem"
                1
              ];
              cmd-3 = [
                "pane::ActivateItem"
                2
              ];
              cmd-4 = [
                "pane::ActivateItem"
                3
              ];
              cmd-5 = [
                "pane::ActivateItem"
                4
              ];
              cmd-6 = [
                "pane::ActivateItem"
                5
              ];
              cmd-7 = [
                "pane::ActivateItem"
                6
              ];
              cmd-8 = [
                "pane::ActivateItem"
                7
              ];
              cmd-9 = [
                "pane::ActivateItem"
                8
              ];
              cmd-0 = [
                "pane::ActivateItem"
                9
              ];
            };
          }
        ];
        extensions = [
          "base16"
          "basher"
          "biome"
          "caddyfile"
          "cargo-tom"
          "discord-presence"
          "env"
          "http"
          "ini"
          "make"
          "dockerfile"
          "docker-compose"
          "sql"
          "nix"
          "nu"
          "log"
          "tombi"
          "nginx"
          "git-firefly"
          "material-icon-theme"
          "xml"
        ];
      };
    }
  ];
}
