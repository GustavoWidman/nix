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
      };
    }

    (mkIf config.isDev {
      programs.gh = enabled {
        settings.git_protocol = "ssh";
      };
    })
  ];
}
