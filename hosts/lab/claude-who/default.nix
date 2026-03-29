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

    extraPackages = with pkgs; [
      jujutsu
      openssh
      bun
      pkg-config
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

  # add oracle as a home-manager user
  home-manager.users = {
    ${config.services.claude-who.user}.home = {
      stateVersion = "25.05";
      homeDirectory = "/home/${config.services.claude-who.user}";
    };
  };

  environment.systemPackages = with pkgs; [
    claude-who.packages.${config.metadata.architecture}.default
    chromium # make chromium available system-wide for the playwright MCP
  ];
}
