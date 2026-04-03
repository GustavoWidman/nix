{
  claude-who,
  config,
  pkgs,
  ...
}:
{
  secrets.claude-who = {
    file = ./settings.json.age;
    mode = "400"; # read-only for owner
    owner = config.services.claude-who.user;
    group = config.services.claude-who.group;
  };

  services.claude-who = {
    enable = true;
    user = "oracle";
    group = "oracle";

    settings = config.secrets.claude-who.path;

    browser.chromiumPackage = pkgs.chromium;

    extraPackages = with pkgs; [
      pkg-config
      jujutsu
      openssh
      codex
      bun
    ];

    environment = {
      PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.onnxruntime.dev}/lib/pkgconfig";
      OPENSSL_DIR = "${pkgs.openssl.dev}";
      OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
      OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
      ORT_DYLIB_PATH = "${pkgs.onnxruntime}/lib/libonnxruntime.so";
      LD_LIBRARY_PATH = "${pkgs.openssl.out}/lib:${pkgs.onnxruntime}/lib:${pkgs.stdenv.cc.cc.lib}/lib";
    };
  };

  # Extend the claude-who service PATH with user-managed tool envs.
  # systemd's `path` option appends /bin to each entry.
  systemd.services.claude-who.path = [
    "/home/oracle/.browser-use-env" # browser-use CLI (installed via pip into user venv)
  ];

  # add oracle as a home-manager user
  home-manager.users = {
    ${config.services.claude-who.user}.home = {
      stateVersion = "25.05";
      homeDirectory = "/home/${config.services.claude-who.user}";
    };
  };

  environment.systemPackages = with pkgs; [
    claude-who.packages.${config.metadata.architecture}.default
  ];
}
