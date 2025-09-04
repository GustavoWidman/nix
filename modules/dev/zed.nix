{
  config,
  self,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    attrsToList
    subtractLists
    optionals
    enabled
    filter
    mkIf
    ;
in
{
  home-manager.sharedModules = [
    {
      programs.zed-editor = enabled {
        package = pkgs.zed-editor;
        userSettings = {
          ssh_connections =
            self.machineMetadata
            |> attrsToList
            |> filter ({ name, value }: (name != config.networking.hostName) && (value.type == "dev-server"))
            |> map (
              { name, ... }:
              {
                host = name;
                projects = [ ];
              }
            );
          icon_theme = "Material Icon Theme";
          autosave = "on_focus_change";
          theme = "Base16 Gruvbox dark, medium";
          buffer_font_family = "Fira Code";
          buffer_font_size = 14;
          terminal.button = false;
          show_whitespaces = "selection";
          read_ssh_config = true;
          debugger.button = false;
          close_on_file_delete = true;
          soft_wrap = "bounded";
          show_wrap_guides = false;
          preferred_line_length = 105;
          telemetry = {
            metrics = false;
            diagnostics = false;
          };
          project_panel.indent_size = 16;
          tabs = {
            file_icons = true;
            git_status = true;
          };
          git.inline_blame.delay_ms = 300;
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
          languages = {
            "Nix".formatter."external" = {
              command = "nixfmt";
              arguments = [ "-q" ];
            };
            "Python" = {
              language_servers = [
                "ruff"
                "pyright"
              ];
              formatter = [
                {
                  language_server.name = "ruff";
                }
              ];
            };
            JSON = {
              formatter = [
                {
                  language_server = {
                    name = "biome";
                  };
                }
              ];
            };
            "Assembly" = {
              formatter = [
                {
                  external = {
                    command = "nasmfmt";
                    arguments = [
                      "-ii"
                      "4"
                      "-ci"
                      "70"
                      "-"
                    ];
                  };
                }
              ];
            };
            JavaScript = {
              formatter = [
                {
                  language_server = {
                    name = "biome";
                  };
                }
              ];
            };
            TypeScript = {
              formatter = [
                {
                  language_server = {
                    name = "biome";
                  };
                }
              ];
            };
          };
          diagnostics.inline.enabled = true;
          features.edit_prediction_provider = "copilot";
          show_edit_predictions = false;
          lsp = {
            discord_presence.initialization_options = {
              application_id = "1263505205522337886";
              base_icons_url = "https://raw.githubusercontent.com/xhyrom/zed-discord-presence/main/assets/icons/";
              state = "Working on {filename}";
              details = "In {workspace}";
              large_image = "{base_icons_url}/{language:lo}.png";
              large_text = "{language:u}";
              small_image = "{base_icons_url}/zed.png";
              small_text = "Zed";
              git_integration = false;
            };
            vscode-html-language-server = {
              binary = {
                path = "${pkgs.vscode-langservers-extracted}/bin/vscode-html-language-server";
                arguments = [ "--stdio" ];
              };
            };
          };
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
        extensions =
          [
            "assembly"
            "base16"
            "basher"
            "biome"
            "caddyfile"
            "cargo-tom"
            "discord-presence"
            "env"
            "http"
            "html"
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
            "ruff"
            "prisma"
            "python-requirements"
            "neocmake"
            "svelte"
          ]
          |> subtractLists (optionals config.isDevServer [ "discord-presence" ]);
      };
    }
    (mkIf config.isDevServer {
      programs.zed-editor.installRemoteServer = true;
    })
  ];
}
