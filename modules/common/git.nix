{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    enabled
    mkIf
    ;
in
{
  home-manager.sharedModules = [
    {
      programs.git = enabled {
        userName = "GustavoWidman (${config.networking.hostName})";
        userEmail = "admin@r3dlust.com";

        lfs = enabled;

        extraConfig = {
          init.defaultBranch = "main";

          column.ui = "auto";

          branch.sort = "-committerdate";
          tag.sort = "version:refname";

          diff.algorithm = "histogram";
          diff.colorMoved = "default";

          pull.rebase = true;
          push.autoSetupRemote = true;

          merge.conflictStyle = "zdiff3";

          rebase.autoSquash = true;
          rebase.autoStash = true;
          rebase.updateRefs = true;
          rerere.enabled = true;

          fetch.fsckObjects = true;
          receive.fsckObjects = true;
          transfer.fsckobjects = true;

          url."ssh://git@github.com/".insteadOf = "https://github.com/";

          commit.gpgSign = true;
          tag.gpgSign = true;

          gpg.format = "ssh";
          user.signingKey = "~/.ssh/id_ed25519";

        };

        ignores = [
          # macOS
          ".DS_Store"
          ".AppleDouble"
          ".LSOverride"

          # The usual culprits
          ".env"

          # IDEs
          ".vscode/"
          ".idea/"
          "*.swp"
          "*.swo"
          "*~"

          # Mise
          "mise.toml"

          # NodeJS
          "node_modules/"
          ".docusaurus"
          ".cache-loader"

          # Nix
          "result"
          "result-*"

          # Nushell Hook
          ".nu"

          # Python
          "*.pyc"
          "__pypackages__/"
          "__pycache__/"
          ".ruff_cache/"
          ".ropeproject"
          ".venv"
          "env/"
          "venv/"
          "ENV"
          "env.bak/"
          "venv.bak/"
          ".python-version"
          "Pipfile.lock"
          "uv.lock"
          "poetry.lock"
          "pdm.lock"
          ".pdm.toml"
          ".pdm-python"
          ".pdm-build/"

          # Rust
          "target/"
        ];
      };
    }

    (mkIf config.isDev {
      programs.gh = enabled {
        settings.git_protocol = "ssh";
      };
    })
  ];
}
