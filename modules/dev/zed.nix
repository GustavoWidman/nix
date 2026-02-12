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
          load_direnv = "direct";
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
            "Nix" = {
              formatter.external = {
                command = "nixfmt";
                arguments = [ "-q" ];
              };
              language_servers = [
                "!nil"
                "nixd"
                "discord_presence"
              ];
            };
            "Python" = {
              language_servers = [
                "ruff"
                "pyright"
                "discord_presence"
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
                    name = "oxfmt";
                  };
                }
                {
                  code_action = "source.fixAll.oxc";
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
                    name = "oxfmt";
                  };
                }
                {
                  code_action = "source.fixAll.oxc";
                }
              ];
            };
            TypeScript = {
              formatter = [
                {
                  language_server = {
                    name = "oxfmt";
                  };
                }
                {
                  code_action = "source.fixAll.oxc";
                }
              ];
            };
          };
          diagnostics.inline.enabled = true;
          features.edit_prediction = {
            provider = "copilot";
            mode = "subtle";
          };
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
              idle.timeout = 0;
            };
            vscode-html-language-server = {
              binary = {
                path = "${pkgs.vscode-langservers-extracted}/bin/vscode-html-language-server";
                arguments = [ "--stdio" ];
              };
            };
            nil = {
              settings = {
                nix = {
                  flake = {
                    autoEvalInputs = true;
                    nixpkgsInputName = "nixpkgs";
                  };
                };
              };
            };
            nixd = {
              settings = {
                nixpkgs = {
                  expr = ''
                    let
                      flake = builtins.getFlake (builtins.toString ./.);
                      real = flake.inputs.nixpkgs;
                      lib = flake.lib or real.lib;

                      nixpkgs = real // {
                        lib = lib;
                        outputs.lib = lib;
                      };
                    in (import nixpkgs { })
                  '';
                };
                options = {
                  nixd = {
                    expr = /* nix */ ''
                      let
                        flake = builtins.getFlake (builtins.toString ./.);
                        default = {
                          users.type.getSubOptions = options: { };
                        };
                        lib = flake.lib or flake.inputs.nixpkgs.lib;

                        darwin = (builtins.attrValues (flake.darwinConfigurations or { }));
                        nixos = (builtins.attrValues (flake.nixosConfigurations or { }));
                        home = (builtins.attrValues (flake.homeConfigurations or { }));
                        all = darwin ++ nixos ++ home;

                        home-manager-options = flake: (flake.options.home-manager or default).users.type.getSubOptions [ ];
                        home-manager = builtins.foldl' (acc: elem: acc // (home-manager-options elem)) { } all;

                        systems = builtins.foldl' (acc: elem: acc // elem.options) { } all;

                        final-flake = flake // {
                          lib = lib;
                          self = flake;
                        };

                        final = ((home-manager // systems) // final-flake);
                      in final
                    '';
                  };
                };
              };
            };
            oxlint = {
              initialization_options = {
                settings = {
                  disableNestedConfig = false;
                  fixKind = "safe_fix";
                  run = "onType";
                  typeAware = true;
                  unusedDisableDirectives = "deny";
                };
              };
            };
            oxfmt = {
              initialization_options = {
                settings = {
                  configPath = null;
                  flags = { };
                  "fmt.configPath" = null;
                  "fmt.experimental" = true;
                  run = "onSave";
                  typeAware = false;
                  unusedDisableDirectives = false;
                };
              };
            };
            clangd = {
              initialization_options = {
                fallbackFlags = [ "-nostdinc++" ];
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
            "caddyfile"
            "discord-presence"
            "env"
            "emmet"
            "http"
            "html"
            "ini"
            "make"
            "oxc"
            "dockerfile"
            "docker-compose"
            "java"
            "sql"
            "nix"
            "nu"
            "log"
            "lua"
            "nginx"
            "git-firefly"
            "material-icon-theme"
            "xml"
            "php"
            "prisma"
            "python-requirements"
            "neocmake"
            "svelte"
            "tex"
          ]
          |> subtractLists (optionals config.isDevServer [ "discord-presence" ]);
      };
    }
    (mkIf config.isDevServer {
      programs.zed-editor.installRemoteServer = true;
    })
  ];
}
