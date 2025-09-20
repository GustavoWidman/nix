{
  lib,
  ...
}:
let
  inherit (lib)
    enabled
    ;
in
{
  homebrew.casks = [ "swipeaerospace" ];

  services.aerospace = enabled {
    settings = {
      accordion-padding = 30;
      default-root-container-layout = "tiles";
      after-startup-command = [
        "layout h_tiles"
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

        alt-shift-1 = [
          "move-node-to-workspace 1"
          "workspace 1"
        ];
        alt-shift-2 = [
          "move-node-to-workspace 2"
          "workspace 2"
        ];
        alt-shift-3 = [
          "move-node-to-workspace 3"
          "workspace 3"
        ];
        alt-shift-4 = [
          "move-node-to-workspace 4"
          "workspace 4"
        ];
        alt-shift-5 = [
          "move-node-to-workspace 5"
          "workspace 5"
        ];
        alt-shift-6 = [
          "move-node-to-workspace 6"
          "workspace 6"
        ];
        alt-shift-7 = [
          "move-node-to-workspace 7"
          "workspace 7"
        ];
        alt-shift-8 = [
          "move-node-to-workspace 8"
          "workspace 8"
        ];
        alt-shift-9 = [
          "move-node-to-workspace 9"
          "workspace 9"
        ];
        alt-shift-0 = [
          "move-node-to-workspace 10"
          "workspace 10"
        ];

        # alt-minus = "resize smart -50";
        # alt-equal = "resize smart +50";

        alt-tab = "workspace-back-and-forth";
        # cmd-shift-tab = "move-workspace-to-monitor --wrap-around next";
      };

      on-window-detected = [
        {
          "if" = {
            app-id = "dev.zed.Zed";
          };
          check-further-callbacks = false;
          run = [ "move-node-to-workspace 1" ];
        }
        {
          "if" = {
            app-id = "com.mitchellh.ghostty";
          };
          check-further-callbacks = false;
          run = [
            "layout floating"
            "move-node-to-workspace 2"
          ];
        }
        {
          "if" = {
            app-id = "app.zen-browser.zen";
          };
          check-further-callbacks = false;
          run = [ "move-node-to-workspace 3" ];
        }
        {
          "if" = {
            app-id = "com.hnc.Discord";
          };
          check-further-callbacks = false;
          run = [ "move-node-to-workspace 4" ];
        }
        {
          "if" = {
            app-id = "net.whatsapp.WhatsApp";
          };
          check-further-callbacks = false;
          run = [ "move-node-to-workspace 4" ];
        }
        {
          "if" = {
            app-id = "com.apple.systempreferences";
          };
          check-further-callbacks = false;
          run = [ "layout floating" ];
        }
        {
          "if" = {
            app-id = "com.apple.SecurityAgent";
          };
          check-further-callbacks = false;
          run = [ "layout floating" ];
        }
        {
          "if" = {
            app-id = "com.apple.finder";
          };
          check-further-callbacks = false;
          run = [ "layout floating" ];
        }
        {
          "if" = {
            app-id = "com.apple.Preview";
          };
          check-further-callbacks = false;
          run = [ "layout floating" ];
        }
        {
          run = [
            "layout floating"
            "move-node-to-workspace 5"
          ];
        }
      ];
    };
  };
}
