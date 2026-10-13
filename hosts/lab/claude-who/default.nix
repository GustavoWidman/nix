{
  config,
  pkgs,
  ...
}:
let
  kacheCacheDir = "/mnt/encrypted/oracle/kache";
in
{
  services.kache.settings.cache.local_store = kacheCacheDir;

  users.groups.kache = {
    gid = 987;
  };
  users.groups.oracle = {
    gid = 991;
  };

  systemd.tmpfiles.rules = [
    "d ${kacheCacheDir} 2775 oracle kache - -"
    "d /mnt/encrypted/oracle/cargo-target 0755 oracle oracle - -"
    "d /mnt/encrypted/oracle/cargo-target/oracle 0755 oracle oracle - -"
    "d /mnt/encrypted/oracle/misc 0755 oracle oracle - -"
    "d /mnt/encrypted/oracle/cargo-target/r3dlust 0755 r3dlust users - -"
  ];

  # add oracle as a home-manager user
  home-manager.users = {
    oracle.home = {
      stateVersion = "25.05";
      homeDirectory = "/home/oracle";
    };
  };

  # add oracle's user to the "docker" group
  users.users.oracle = {
    uid = 993;
    isSystemUser = true;
    group = "oracle";
    home = "/home/oracle";
    createHome = true;
    shell = pkgs.bash;
    extraGroups = [
      "docker"
      "kache"
      "systemd-journal"
    ];
    linger = true;
    authorizedKey = config.secrets.ssh-main-lab.path;
  };

  users.users.r3dlust.extraGroups = [ "kache" ];

  environment.systemPackages = with pkgs; [
    xvfb
    openbox
    dbus
    at-spi2-core
    xmessage
    xrandr
    libx11
    libxi
    libxtst
    libxext
    pipewire
    libei
    libxkbcommon
    x11vnc
    novnc
    python3Packages.websockify
    xorg-server
  ];

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      xorg.libX11
      xorg.libXi
      libxkbcommon
    ];
  };

  systemd.user.services.kache.serviceConfig = {
    ReadWritePaths = [ "/mnt/encrypted" ];
    UMask = "0002";
  };
}
