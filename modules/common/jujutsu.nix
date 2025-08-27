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

            aliases.comi = [
              "commit"
              "--interactive"
            ];
            aliases.bring = [
              "bookmark"
              "set"
              "-r"
              "@-"
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
