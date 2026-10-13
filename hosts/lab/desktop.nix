{
  config,
  lib,
  pkgs,
  ...
}:
let
  tailscaleIP = "100.122.90.22";
  # Nixpkgs disables DRI3 in Xvnc, which otherwise forces llvmpipe.
  tigervncGpu = pkgs.tigervnc.overrideAttrs (old: {
    postBuild = lib.replaceStrings [ "--disable-dri3" ] [ "--enable-dri3" ] old.postBuild;
    buildInputs = old.buildInputs ++ [
      pkgs.mesa
      pkgs.libdrm
    ];
  });
  desktopSession = pkgs.writeShellApplication {
    name = "lab-desktop-session";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      tigervncGpu
      pkgs.xauth
      pkgs.xdpyinfo
      pkgs.xset
      pkgs.xfce4-session
      pkgs.xfconf
    ];
    text = ''
      export DISPLAY=:2
      export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
      export XAUTHORITY="$XDG_RUNTIME_DIR/lab-desktop/Xauthority"
      export XDG_CURRENT_DESKTOP=XFCE
      export XDG_SESSION_DESKTOP=xfce
      export XDG_SESSION_TYPE=x11
      export NO_AT_BRIDGE=0
      export PATH=${config.system.path}/bin:$PATH
      export XDG_CONFIG_DIRS=${config.system.path}/etc/xdg:/etc/xdg
      export XDG_DATA_DIRS=${config.system.path}/share:''${XDG_DATA_DIRS:-}
      touch "$XAUTHORITY"
      chmod 600 "$XAUTHORITY"
      xauth add "$DISPLAY" MIT-MAGIC-COOKIE-1 "$(mcookie)"
      terminal_config="$HOME/.config/xfce4/terminal/terminalrc"
      if [ ! -e "$terminal_config" ]; then
        mkdir -p "$(dirname "$terminal_config")"
        cat > "$terminal_config" <<'TERMINAL'
      [Configuration]
      FontUseSystem=FALSE
      FontName=JetBrainsMono Nerd Font Mono 12
      TERMINAL
      fi

      Xvnc "$DISPLAY" -geometry 1920x1080 -depth 24 -dpi 96 \
        -rfbport 5902 -localhost -SecurityTypes None -AlwaysShared \
        -auth "$XAUTHORITY" -rendernode auto &
      vnc_pid=$!
      trap 'kill "$vnc_pid" 2>/dev/null || true' EXIT
      for attempt in $(seq 1 50); do
        if xdpyinfo >/dev/null 2>&1; then break; fi
        kill -0 "$vnc_pid"
        if [ "$attempt" -eq 50 ]; then
          echo 'Xvnc did not become ready' >&2
          exit 1
        fi
        sleep 0.2
      done
      xdpyinfo >/dev/null
      dbus-update-activation-environment --systemd \
        DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP \
        XDG_SESSION_TYPE XDG_CONFIG_DIRS XDG_DATA_DIRS PATH
      appearance_marker="$HOME/.config/lab-desktop/appearance-v1"
      if [ ! -e "$appearance_marker" ]; then
        xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s Adwaita-dark
        xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s Papirus-Dark
        xfconf-query -c xfwm4 -p /general/theme -n -t string -s Default
        for workspace in 0 1 2 3; do
          backdrop="/backdrop/screen0/monitorVNC-0/workspace$workspace"
          xfconf-query -c xfce4-desktop -p "$backdrop/image-style" -n -t int -s 0
          xfconf-query -c xfce4-desktop -p "$backdrop/color-style" -n -t int -s 0
          xfconf-query -c xfce4-desktop -p "$backdrop/rgba1" -n \
            -t double -t double -t double -t double -s 0.06 -s 0.07 -s 0.09 -s 1
        done
        mkdir -p "$(dirname "$appearance_marker")"
        touch "$appearance_marker"
      fi
      xset s off
      xset -dpms || true
      xfce4-session &
      session_pid=$!
      trap 'kill "$session_pid" "$vnc_pid" 2>/dev/null || true' EXIT
      wait -n "$vnc_pid" "$session_pid"
    '';
  };
  dnsZone = pkgs.writeText "lab.zone" ''
    $ORIGIN lab.
    $TTL 60
    @ IN SOA ns.lab. hostmaster.lab. (1 3600 600 86400 60)
    @ IN NS ns.lab.
    @ IN A ${tailscaleIP}
    ns IN A ${tailscaleIP}
    desktop IN A ${tailscaleIP}
  '';
in
{
  # Run the desktop in Xvnc rather than taking over the VM's console.
  services.xserver.desktopManager.xfce = {
    enable = true;
    enableScreensaver = false;
  };
  services.xserver.displayManager.lightdm.enable = lib.mkForce false;
  services.displayManager.enable = lib.mkForce false;
  services.gnome.at-spi2-core.enable = true;
  services.dbus.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  users.users.r3dlust.linger = true;
  fonts = {
    packages = [ pkgs.nerd-fonts.jetbrains-mono ];
    fontconfig = {
      enable = true;
      defaultFonts.monospace = [ "JetBrainsMono Nerd Font Mono" ];
      antialias = true;
      hinting.style = "slight";
      subpixel.rgba = "none";
    };
  };
  environment.systemPackages = [
    pkgs.google-chrome
    pkgs.xfce4-terminal
    tigervncGpu
    pkgs.mesa-demos
    pkgs.papirus-icon-theme
  ];

  systemd.user.services.lab-desktop = {
    description = "Persistent lab Xfce desktop";
    wantedBy = [ "default.target" ];
    after = [ "dbus.service" ];
    unitConfig.ConditionUser = "r3dlust";
    serviceConfig = {
      ExecStart = "${desktopSession}/bin/lab-desktop-session";
      RuntimeDirectory = "lab-desktop";
      RuntimeDirectoryMode = "0700";
      Restart = "always";
      RestartSec = 5;
      KillMode = "control-group";
      UMask = "0077";
    };
  };

  systemd.services.lab-desktop-novnc = {
    description = "noVNC for the persistent lab desktop";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      DynamicUser = true;
      ExecStart = "${pkgs.python3Packages.websockify}/bin/websockify --web=${pkgs.novnc}/share/webapps/novnc 127.0.0.1:6080 127.0.0.1:5902";
      Restart = "always";
      RestartSec = 5;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

  services.caddy = {
    enable = true;
    # Bind before Tailscale assigns its address; the firewall limits ingress.
    virtualHosts."http://:80".extraConfig = ''
      bind 0.0.0.0
      @root path /
      redir @root /vnc.html?autoconnect=1&resize=scale 302
      reverse_proxy 127.0.0.1:6080
    '';
  };
  systemd.services.caddy = {
    unitConfig.StartLimitIntervalSec = lib.mkForce 0;
    serviceConfig = {
      Restart = lib.mkForce "on-failure";
      RestartPreventExitStatus = lib.mkForce "";
    };
    after = [
      "tailscaled.service"
      "lab-desktop-novnc.service"
    ];
  };

  services.coredns = {
    enable = true;
    config = ''
      lab:53 {
        bind ${tailscaleIP}
        file ${dnsZone} lab.
        errors
      }
    '';
  };
  systemd.services.coredns = {
    after = [ "tailscaled.service" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = lib.mkDefault 5;
    };
  };
  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [
      53
      80
    ];
    allowedUDPPorts = [ 53 ];
  };
}
