{
  lib,
  ...
}:
let
  inherit (lib) enabled;
in
{
  home-manager.sharedModules = [
    (
      homeArgs:
      let
        config' = homeArgs.config;
      in
      {
        programs.jujutsu = enabled {
          settings = {
            user.name = config'.programs.git.settings.user.name;
            user.email = config'.programs.git.settings.user.email;

            ui.diff-editor = ":builtin";

            snapshot.max-new-file-size = "1GiB";

            revset-aliases = {
              "immutable_heads()" = "builtin_immutable_heads() | remote_bookmarks()";
              "working_changes" = "heads(mutable()) & description(exact:'')";
              "closest_bookmark(x)" = "heads(::x & bookmarks())";
              "closest_remote_bookmark(x)" = "heads(::x & remote_bookmarks())";
            };

            aliases.".." = [
              "edit"
              "@-"
            ];
            aliases.",," = [
              "edit"
              "@+"
            ];

            aliases.r = [
              "rebase"
            ];
            aliases."r!" = [
              "rebase"
              "--ignore-immutable"
            ];
            aliases."rebase!" = [
              "rebase"
              "--ignore-immutable"
            ];

            aliases.a = [
              "abandon"
            ];
            aliases."a!" = [
              "abandon"
              "--ignore-immutable"
            ];
            aliases."abandon!" = [
              "abandon"
              "--ignore-immutable"
            ];

            aliases.back = [
              "edit"
              "reachable(@::, working_changes)"
            ];

            aliases.fetch = [
              "git"
              "fetch"
            ];
            aliases.f = [
              "git"
              "fetch"
            ];

            aliases.push = [
              "git"
              "push"
              "-N"
            ];
            aliases.p = [
              "git"
              "push"
              "-N"
            ];

            aliases.clone = [
              "git"
              "clone"
              "--colocate"
            ];
            aliases.cl = [
              "git"
              "clone"
              "--colocate"
            ];

            aliases.init = [
              "git"
              "init"
              "--colocate"
            ];
            aliases.i = [
              "git"
              "init"
              "--colocate"
            ];

            aliases.s = [ "squash" ];
            aliases."s!" = [
              "squash"
              "--ignore-immutable"
            ];
            aliases."squash!" = [
              "squash"
              "--ignore-immutable"
            ];

            aliases.si = [
              "squash"
              "--interactive"
            ];
            aliases."si!" = [
              "squash"
              "--interactive"
              "--ignore-immutable"
            ];
            aliases.squashi = [
              "squash"
              "--interactive"
            ];
            aliases."squashi!" = [
              "squash"
              "--interactive"
              "--ignore-immutable"
            ];

            aliases."split!" = [
              "split"
              "--ignore-immutable"
            ];

            aliases.c = [ "commit" ];
            aliases.ci = [
              "commit"
              "--interactive"
            ];
            aliases.comi = [
              "commit"
              "--interactive"
            ];

            aliases.e = [ "edit" ];
            aliases."e!" = [
              "edit"
              "--ignore-immutable"
            ];
            aliases."edit!" = [
              "edit"
              "--ignore-immutable"
            ];

            aliases.d = [ "describe" ];
            aliases."d!" = [
              "describe"
              "--ignore-immutable"
            ];
            aliases."describe!" = [
              "describe"
              "--ignore-immutable"
            ];

            aliases.history = [
              "log"
              "-r"
              "all()"
            ];
            aliases.pov = [
              "log"
              "-r"
              "closest_bookmark(@)::@"
            ];

            aliases.tug = [
              "bookmark"
              "move"
              "--from"
              "closest_bookmark(@-)"
              "--to"
              "@-"
            ];
            aliases.t = [ "tug" ];

            aliases.bring = [
              "rebase"
              "-b"
              "@"
              "-d"
            ];

            aliases.remote = [
              "git"
              "remote"
            ];

            git.auto-local-bookmark = true;

            git.fetch = [
              "origin"
            ];
            git.push = "origin";

            signing.backend = "ssh";
            signing.behavior = "own";
            signing.key = "~/.ssh/id_ed25519";
          };
        };
      }
    )
  ];
}
