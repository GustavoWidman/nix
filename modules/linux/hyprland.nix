{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mergeIf
    ;
in
mergeIf (config.isDesktop) {
  # Optional: If you have NVIDIA, enable patches for better compatibility
  # programs.hyprland.nvidiaPatches = true;
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # Use SDDM as display manager (Wayland-friendly; auto-starts Hyprland after login)
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;

  # Optional: Auto-login for convenience (replace "yourusername" with yours)
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "r3dlust";

  # Install system-wide packages if needed (e.g., for fonts or utils)
  # environment.systemPackages = with pkgs; [
  #   # Fonts for better looks (Nerd Fonts for icons in Waybar/Wofi)
  #   (nerdfonts.override {
  #     fonts = [
  #       "FiraCode"
  #       "JetBrainsMono"
  #     ];
  #   })
  # ];

  # Enable sound (PulseAudio or PipeWire; Hyprland works with either)
  # sound.enable = true;
  services.pulseaudio.enable = false; # Use PipeWire instead for Wayland
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Install your usual apps and Hyprland helpers
  home-manager.sharedModules = [
    {
      home.packages = with pkgs; [
        # Terminals/Browsers/Editors
        ghostty # Your terminal
        zed-editor # Zed
        vscode # VSCode
        inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default # Zen Browser
        google-chrome # Chrome
        discord # Discord
        # webcord # For WhatsApp (Electron wrapper; or use browser)

        # Hyprland essentials for looks/function
        wofi # App launcher/search
        waybar # Status bar
        hyprpaper # Wallpaper
        swww # Alternative wallpaper if needed
        dunst # Notifications (better than default)
        libnotify # For notify-send testing

        # Theming (for consistent looks)
        # gnome.gnome-themes-extra # GTK themes
        # qt5ct # QT theme config
        papirus-icon-theme # Icons
      ];

      home.pointerCursor = {
        gtk.enable = true;
        x11.enable = true;
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Classic";
        size = 24;
      };

      # Basic Waybar config (top bar with workspaces, clock, battery, etc.)
      programs.waybar = {
        enable = true;
        settings = {
          mainBar = {
            layer = "top";
            position = "top";
            height = 30;
            modules-left = [ "hyprland/workspaces" ];
            modules-center = [ "clock" ];
            modules-right = [
              "pulseaudio"
              "network"
              "cpu"
              "memory"
              "battery"
              "tray"
            ];
            # Customize further as needed
          };
        };
        style = ''
          * { font-family: JetBrainsMono Nerd Font; font-size: 12px; }
          window#waybar { background: rgba(0,0,0,0.5); color: #ffffff; }
          /* Add more CSS for looks */
        '';
      };

      # Hyprpaper for wallpaper (edit path to your image)
      services.hyprpaper = {
        enable = true;
        settings = {
          ipc = "on";
          splash = false;
          preload = [
            "${toString ./f40-wpp.png}"
          ];
          wallpaper = [ ",${toString ./f40-wpp.png}" ]; # "," for all monitors
        };
      };

      # Enable Hyprland in Home Manager
      wayland.windowManager.hyprland = {
        enable = true;
        xwayland.enable = true; # For compatibility
        settings = {
          # Mod key: ALT (like your Aerospace; change to "SUPER" if conflicts)
          "$mod" = "MOD1";

          exec-once = [
            "waybar" # This starts waybar reliably
            "hyprpaper" # Already running, but ensures it's launched by Hyprland
            "dunst" # Notifications (optional but useful)
          ];

          # General settings (gaps, borders, layout)
          general = {
            gaps_in = 8;
            gaps_out = 4;
            border_size = 2;
            "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
            "col.inactive_border" = "rgba(595959aa)";
            layout = "master"; # Stack/accordion-like to match Aerospace
          };

          # Decoration (blur, rounding, shadows for good looks)
          decoration = {
            rounding = 10;
            blur = {
              enabled = true;
              size = 3;
              passes = 1;
            };
            drop_shadow = true;
            shadow_range = 4;
            shadow_render_power = 3;
            "col.shadow" = "rgba(1a1a1aee)";
          };

          # Animations (smooth fades/slides)
          animations = {
            enabled = true;
            bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
            animation = [
              "windows, 1, 7, myBezier"
              "windowsOut, 1, 7, default, popin 80%"
              "border, 1, 10, default"
              "borderangle, 1, 8, default"
              "fade, 1, 7, default"
              "workspaces, 1, 6, default"
            ];
          };

          # Master layout (accordion padding like yours)
          master = {
            new_is_master = true;
            mfact = 0.55; # Split ratio
            # No direct accordion-padding equivalent, but gaps handle spacing
          };

          # Input (keyboard layout, etc.)
          input = {
            kb_layout = "us";
            follow_mouse = 1;
            sensitivity = 0; # Adjust if needed
          };

          # Misc (disable default wallpaper, force focus)
          misc = {
            force_default_wallpaper = 0;
            disable_hyprland_logo = true;
          };

          # Keybinds (translated from your Aerospace)
          bind = [
            "$mod, F, fullscreen, 0" # Fullscreen (0 for normal, 1 for max)
            "$mod, H, movefocus, l" # Focus left (h=jkl directions: h=left, l=right, j=down, k=up)
            "$mod, L, movefocus, r"
            "$mod, J, movefocus, d"
            "$mod, K, movefocus, u"
            "$mod SHIFT, H, movewindow, l" # Move window
            "$mod SHIFT, L, movewindow, r"
            "$mod SHIFT, J, movewindow, d"
            "$mod SHIFT, K, movewindow, u"
            "$mod, TAB, cyclenext," # Focus next (wrap around)
            "$mod, TAB, bringactivetotop," # Bring to front
            "$mod SHIFT, TAB, cyclenext, prev" # Focus prev
            "$mod, 1, workspace, 1"
            "$mod, 2, workspace, 2"
            "$mod, 3, workspace, 3"
            "$mod, 4, workspace, 4"
            "$mod, 5, workspace, 5"
            "$mod, 6, workspace, 6"
            "$mod, 7, workspace, 7"
            "$mod, 8, workspace, 8"
            "$mod, 9, workspace, 9"
            "$mod, 0, workspace, 10"
            "$mod SHIFT, 1, movetoworkspace, 1"
            "$mod SHIFT, 2, movetoworkspace, 2"
            "$mod SHIFT, 3, movetoworkspace, 3"
            "$mod SHIFT, 4, movetoworkspace, 4"
            "$mod SHIFT, 5, movetoworkspace, 5"
            "$mod SHIFT, 6, movetoworkspace, 6"
            "$mod SHIFT, 7, movetoworkspace, 7"
            "$mod SHIFT, 8, movetoworkspace, 8"
            "$mod SHIFT, 9, movetoworkspace, 9"
            "$mod SHIFT, 0, movetoworkspace, 10"
            "$mod, Z, resizeactive, equal" # Balance sizes (like alt-z in Aerospace)
            "$mod SHIFT, Z, pseudo," # Reload config
            "$mod, space, exec, wofi --show drun" # App launcher/search
            # Add more: e.g., "$mod, Q, exit," to quit Hyprland
          ];

          # Window rules (assign to workspaces, float; based on your Aerospace on-window-detected)
          # Use `hyprctl clients` in a terminal to find exact class/title for apps
          windowrulev2 = [
            "workspace 1, class:^(Zed)$" # Zed to workspace 1
            "workspace 1, class:^(code-url-handler)$" # VSCode
            "workspace 2, class:^(ghostty)$" # Ghostty terminal
            "workspace 2, class:^(org.wezfurlong.wezterm)$" # Or another terminal if needed
            "workspace 3, class:^(zen-browser)$" # Zen Browser
            "workspace 3, class:^(google-chrome)$" # Chrome
            "workspace 4, class:^(discord)$" # Discord
            "workspace 4, class:^(vesktop)$" # WhatsApp (use vesktop or webcord for WhatsApp/Discord combo)
            "float, class:^(zen-browser)$, title:(Bitwarden)" # Float Bitwarden in Zen
            "float, class:^(Zed)$, title:(Settings)" # Float Zed settings
            "float, class:^(discord)$, title:(Call)" # Float calls
            "float, class:^(org.gnome.Nautilus)$" # File manager
            "float, class:^(org.gnome.Calculator)$" # Calculator
            "float, class:^(pavucontrol)$" # Volume control
            "float, title:(Preferences|Settings|About)$" # Generic float for popups
            # Default to workspace 5 for unknowns
            "workspace 5 silent, class:.*"
          ];
        };
      };
    }
  ];

  # GTK theme for apps (dark mode, adwaita-like for good looks)
  # gtk = {
  #   enable = true;
  #   theme = {
  #     name = "Adwaita";
  #     package = pkgs.gnome.adwaita-icon-theme;
  #   };
  #   iconTheme = {
  #     name = "Papirus";
  #     package = pkgs.papirus-icon-theme;
  #   };
  # };

}
