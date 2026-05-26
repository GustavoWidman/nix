{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) enabled;
in
{
  environment.systemPackages = with pkgs; [
    mergiraf
    difftastic
    jjui
  ];

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

            ui.default-command = "ls";
            ui.diff-editor = ":builtin";
            ui.diff-formatter = [
              "difft"
              "--color"
              "always"
              "$left"
              "$right"
            ];
            ui.conflict-marker-style = "snapshot";
            ui.graph.style = "curved";

            snapshot.max-new-file-size = "1GiB";

            merge.hunk-level = "word";

            revset-aliases = {
              "close" = "closest_bookmark(@-)";
              "immutable_heads()" = "builtin_immutable_heads() | remote_bookmarks()";
              "working_changes" = "heads(mutable()) & description(exact:'')";
              "closest_bookmark(x)" = "heads(::x & bookmarks())";
              "closest_remote_bookmark(x)" = "heads(::x & remote_bookmarks())";
            };

            templates.file_annotate = ''join(" ", commit.change_id().shortest(8), pad_end(16, truncate_end(16, commit.author().name())), pad_start(4, line_number)) ++ ": " ++ content'';

            # back & forth
            aliases.".." = [
              "edit"
              "@-"
            ];
            aliases.",," = [
              "edit"
              "@+"
            ];

            # abandon
            aliases.a = [ "abandon" ];
            aliases."a!" = [
              "a"
              "--ignore-immutable"
            ];
            aliases."abandon!" = [ "a!" ];

            # arrange
            aliases."arr" = [ "arrange" ];

            aliases.back = [
              "edit"
              "reachable(@::, working_changes)"
            ];

            # bookmark operations
            aliases.bc = [
              "bookmark"
              "create"
            ];
            aliases.bn = [
              "bookmark"
              "create"
            ];
            aliases.cb = [
              "bookmark"
              "create"
            ];
            aliases.nb = [
              "bookmark"
              "create"
            ];

            aliases.bf = [
              "bookmark"
              "forget"
            ];
            aliases.bl = [
              "bookmark"
              "list"
            ];
            aliases.br = [
              "bookmark"
              "rename"
            ];
            aliases.bt = [
              "bookmark"
              "track"
            ];
            aliases.bu = [
              "bookmark"
              "untrack"
            ];

            aliases.bm = [
              "bookmark"
              "move"
            ];
            aliases."bm!" = [
              "bm"
              "--allow-backwards"
            ];

            aliases.bs = [
              "bookmark"
              "set"
            ];
            aliases."bs!" = [
              "bs"
              "--allow-backwards"
            ];

            # commit
            aliases.c = [ "commit" ];
            aliases.ci = [
              "commit"
              "--interactive"
            ];
            aliases.comi = [ "ci" ];

            # describe
            aliases.d = [ "describe" ];
            aliases."d!" = [
              "d"
              "--ignore-immutable"
            ];
            aliases."describe!" = [ "d!" ];

            # edit
            aliases.e = [ "edit" ];
            aliases."e!" = [
              "e"
              "--ignore-immutable"
            ];
            aliases."edit!" = [ "e!" ];

            # linear history
            aliases.history = [
              "log"
              "-r"
              "all()"
            ];
            aliases.h = [ "history" ];

            aliases.ls = [
              "log"
              "--summary"
            ];
            aliases.pov = [
              "log"
              "-r"
              "closest_bookmark(@)::@"
            ];

            aliases.working = [
              "log"
              "-r"
              "working_changes"
            ];
            aliases.wc = [ "working" ];

            aliases.mutable = [
              "log"
              "-r"
              "mutable()"
            ];

            # rebase
            aliases.r = [
              "rebase"
            ];
            aliases."r!" = [
              "r"
              "--ignore-immutable"
            ];
            aliases."rebase!" = [ "r!" ];

            aliases.bring = [
              "rebase"
              "-b"
              "@"
              "-d"
            ];

            # make a github merge commit.
            # usage "jj merge main"
            # merges "current branch" with the tip of another branch (or many branches),
            # making @ the "merge commit" and leaving potential conflicts in @ to be commited.
            # @ should then be described and pushed as a "merge" commit
            aliases.merge = [
              "new"
              "close"
            ];

            # git
            aliases.remote = [
              "git"
              "remote"
            ];

            aliases.push = [
              "git"
              "push"
            ];
            aliases.p = [ "push" ];

            aliases.fetch = [
              "git"
              "fetch"
            ];
            aliases.f = [ "fetch" ];

            aliases.init = [
              "git"
              "init"
              "--colocate"
            ];
            aliases.i = [ "init" ];

            aliases.clone = [
              "git"
              "clone"
              "--colocate"
            ];
            aliases.cl = [ "clone" ];

            # resolve
            aliases.resolve-ast = [
              "resolve"
              "--tool"
              "mergiraf"
            ];
            aliases.resa = [ "resolve-ast" ];

            # squash
            aliases.s = [ "squash" ];
            aliases."s!" = [
              "s"
              "--ignore-immutable"
            ];
            aliases."squash!" = [ "s!" ];

            aliases.si = [
              "s"
              "--interactive"
            ];
            aliases."si!" = [
              "si"
              "--ignore-immutable"
            ];

            aliases.squashi = [ "si" ];
            aliases."squashi!" = [ "si!" ];

            aliases."split!" = [
              "split"
              "--ignore-immutable"
            ];

            aliases.tug = [
              "bookmark"
              "move"
              "--to"
              "@-"
              "--from"
            ];
            aliases.t = [ "tug" ];

            aliases.blame = [
              "file"
              "annotate"
            ];

            aliases.untrack = [
              "file"
              "untrack"
            ];
            aliases.u = [ "untrack" ];

            # syncs the local with the remote and places '@' on top of the bookmark we are tracking,
            # which is usually the "closest" bookmark to our current position.
            # used to quickly update our local branch to the latest remote changes,
            # while keeping our local commits on top of the updated bookmark.
            aliases.sync = [
              "util"
              "exec"
              "--"
              "sh"
              "-c"
              "bookmark=$(jj log -r 'closest_bookmark(@)' -T 'bookmarks' --no-graph) && jj fetch && jj new $bookmark"
            ];

            remotes.origin.auto-track-bookmarks = "glob:*";

            git.fetch = [
              "origin"
            ];
            git.push = "origin";

            signing.backend = "ssh";
            signing.behavior = "own";
            signing.key = "${config'.home.homeDirectory}/.ssh/id_ed25519";
          };
        };
      }
    )
  ];
}
