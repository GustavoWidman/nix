{
  lib,
  ...
}:
let
  inherit (lib)
    enabled
    ;

  mkWorkspaceEntry = app-id: id: float: {
    "if".app-id = app-id;
    check-further-callbacks = false;
    run = (lib.lists.optional float "layout floating") ++ [
      "move-node-to-workspace ${toString id}"
    ];
  };
  mkFloat = app-id: check-further-callbacks: {
    inherit check-further-callbacks;
    "if".app-id = app-id;
    run = [ "layout floating" ];
  };
  mkFloatTitle = app-id: app-title: check-further-callbacks: {
    inherit check-further-callbacks;
    "if" = {
      inherit app-id;
      window-title-regex-substring = app-title;
    };
    run = [ "layout floating" ];
  };
in
{
  services.aerospace = enabled {
    settings = {
      accordion-padding = 160;
      default-root-container-layout = "accordion";
      after-startup-command = [
        "layout accordion"
      ];

      gaps = {
        inner.horizontal = 8;
        inner.vertical = 8;
        outer.left = 4;
        outer.bottom = 4;
        outer.top = 4;
        outer.right = 4;
      };
      mode.main.binding = {
        cmd-h = [ ];
        cmd-alt-h = [ ];

        alt-f = "fullscreen";

        alt-h = "focus left";
        alt-j = "focus down";
        alt-k = "focus up";
        alt-l = "focus right";

        alt-shift-h = "move left";
        alt-shift-j = "move down";
        alt-shift-k = "move up";
        alt-shift-l = "move right";

        alt-tab = "focus dfs-next --boundaries-action wrap-around-the-workspace";
        alt-shift-tab = "focus dfs-prev --boundaries-action wrap-around-the-workspace";

        alt-1 = "workspace 1";
        alt-2 = "workspace 2";
        alt-3 = "workspace 3";
        alt-4 = "workspace 4";
        alt-5 = "workspace 5";
        alt-6 = "workspace 6";
        alt-7 = "workspace 7";
        alt-8 = "workspace 8";
        alt-9 = "workspace 9";
        alt-0 = "workspace 10";

        alt-shift-1 = "move-node-to-workspace --focus-follows-window 1";
        alt-shift-2 = "move-node-to-workspace --focus-follows-window 2";
        alt-shift-3 = "move-node-to-workspace --focus-follows-window 3";
        alt-shift-4 = "move-node-to-workspace --focus-follows-window 4";
        alt-shift-5 = "move-node-to-workspace --focus-follows-window 5";
        alt-shift-6 = "move-node-to-workspace --focus-follows-window 6";
        alt-shift-7 = "move-node-to-workspace --focus-follows-window 7";
        alt-shift-8 = "move-node-to-workspace --focus-follows-window 8";
        alt-shift-9 = "move-node-to-workspace --focus-follows-window 9";
        alt-shift-0 = "move-node-to-workspace --focus-follows-window 10";

        alt-shift-z = "reload-config";
        alt-z = "balance-sizes";

        # alt-minus = "resize smart -50";
        # alt-equal = "resize smart +50";

        # cmd-shift-tab = "move-workspace-to-monitor --wrap-around next";
      };

      on-window-detected = [
        (mkFloatTitle "app.zen-browser.zen" "bitwarden" true)
        (mkFloatTitle "dev.zed.Zed" "settings" true)
        (mkFloatTitle "dev.zed.Zed-Nightly" "settings" true)
        (mkFloatTitle "net.whatsapp.WhatsApp" "call" true)
        (mkFloatTitle "com.hnc.Discord" "call" true)

        # Workspace 1 - Code
        (mkWorkspaceEntry "dev.zed.Zed" 1 false)
        (mkWorkspaceEntry "dev.zed.Zed-Nightly" 1 false)
        (mkWorkspaceEntry "com.microsoft.VSCode" 1 false)

        # Workspace 2 - Terminal
        (mkWorkspaceEntry "com.mitchellh.ghostty" 2 true)
        (mkWorkspaceEntry "com.apple.Terminal" 2 true)

        # Workspace 3 - Browser
        (mkWorkspaceEntry "app.zen-browser.zen" 3 false)
        (mkWorkspaceEntry "com.apple.Safari" 3 false)
        (mkWorkspaceEntry "com.google.Chrome" 3 false)

        # Workspace 4 - Social
        (mkWorkspaceEntry "com.hnc.Discord" 4 false)
        (mkWorkspaceEntry "net.whatsapp.WhatsApp" 4 false)

        (mkFloat "com.apple.systempreferences" false)
        (mkFloat "com.apple.SecurityAgent" false)
        (mkFloat "com.apple.finder" false)
        (mkFloat "com.apple.Preview" false)
        (mkFloat "com.apple.QuickTimePlayerX" false)
        (mkFloat "com.apple.ScreenContinuity" false)
        (mkFloat "com.raycast.macos" false)
        (mkFloat "com.apple.SystemProfiler" false)
        (mkFloat "com.docker.docker" false)
        (mkFloat "com.electron.dockerdesktop" false)
        (mkFloat "com.apple.mobilephone" false)

        # Workspace 5 - etc
        {
          run = [
            "move-node-to-workspace 5"
          ];
        }
      ];
    };
  };

  # home-manager.sharedModules = [
  #   {
  #     imports = [
  #       aerospace-swipe-nix.homeManagerModules.default
  #     ];

  #     services.aerospace-swipe = enabled {
  #       config = {
  #         haptic = true;
  #         natural_swipe = true;
  #         wrap_around = true;
  #         skip_empty = false;
  #         fingers = 3;
  #       };
  #     };
  #   }
  # ];
}
