{
  config,
  pkgs,
  ...
}:
let
  playwrightBrowserShim = pkgs.runCommand "playwright-chromium-shim" { } ''
    mkdir -p $out/chromium-0/chrome-linux64
    ln -s ${pkgs.chromium}/bin/chromium $out/chromium-0/chrome-linux64/chrome
  '';
in
{
  secrets.hermes-env = {
    file = ./hermes.env.age;
    mode = "400"; # read-only for owner
    owner = config.services.hermes-agent.user;
    group = config.services.hermes-agent.group;
  };

  secrets.hermes-auth = {
    file = ./auth.json.age;
    mode = "400"; # read-only for owner
    owner = config.services.hermes-agent.user;
    group = config.services.hermes-agent.group;
  };

  services.hermes-agent = {
    enable = true;
    user = "oracle";
    group = "oracle";

    addToSystemPackages = true;
    settings = {
      model = {
        # default = "glm-5.1";
        default = "gpt-5.4-mini";
        # provider = "zai";
        provider = "openai-codex";
        # base_url = "https://api.z.ai/api/coding/paas/v4";
        base_url = "https://chatgpt.com/backend-api/codex";
      };
    };
    stateDir = "/home/${config.services.hermes-agent.user}";
    environment = {
      PLAYWRIGHT_BROWSERS_PATH = "${playwrightBrowserShim}";
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      BUN_INSTALL = "/home/${config.services.hermes-agent.user}/.bun";
    };
    extraPackages = with pkgs; [
      # claude-code
      chromium
      jujutsu
      openssh
      codex
      bun
    ];
    authFile = config.secrets.hermes-auth.path;
    environmentFiles = [ config.secrets.hermes-env.path ];
  };

  systemd.services.hermes-agent.path = [
    "/home/${config.services.hermes-agent.user}/.bun"
  ];

  # add oracle as a home-manager user
  home-manager.users = {
    ${config.services.hermes-agent.user}.home = {
      stateVersion = "25.05";
      homeDirectory = "/home/${config.services.hermes-agent.user}";
    };
  };
}
