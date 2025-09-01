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
            user.name = config'.programs.git.userName;
            user.email = config'.programs.git.userEmail;

            aliases.".." = [
              "edit"
              "@-"
            ];
            aliases.",," = [
              "edit"
              "@+"
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
            ];
            aliases.p = [
              "git"
              "push"
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
            aliases.si = [
              "squash"
              "--interactive"
            ];

            aliases."squash!" = [
              "squash"
              "--ignore-immutable"
            ];
            aliases."s!" = [
              "squash"
              "--ignore-immutable"
            ];
            aliases."si!" = [
              "squash"
              "--interactive"
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
            aliases."edit!" = [
              "edit"
              "--ignore-immutable"
            ];
            aliases."e!" = [
              "edit"
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

            aliases.tug = [
              "bookmark"
              "move"
              "--from"
              "heads(::@- & bookmarks())"
              "--to"
              "@-"
            ];
            aliases.t = [ "tug" ];

            aliases.back = [
              "edit"
              "main+"
            ];

            aliases.remote = [
              "git"
              "remote"
            ];

            git.auto-local-bookmark = true;

            git.fetch = [
              "origin"
              "upstream"
              "rad"
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
