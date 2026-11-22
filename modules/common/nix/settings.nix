{
  inputs,
  config,
  self,
  lib,
  pkgs,
  isDarwin,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    mapAttrsToList
    filterAttrs
    mapAttrs
    optionalAttrs
    remove
    mkForce
    mkAfter
    mkMerge
    isType
    const
    id
    ;

  # the config's own source would make every commit a new generation on every
  # machine, even one that touches a single host, and nothing looks it up
  flakes = removeAttrs inputs [ "self" ] |> filterAttrs (const <| isType "flake");
  registry = flakes // { default = inputs.nixpkgs; } |> mapAttrs (_: flake: { inherit flake; });

  extra-platforms = remove config.metadata.architecture config.metadata.build-architectures;
  # extra-platforms = [ ] turns off nix's default platforms (i686-linux,
  # x86_64-v*), so it is set only when the machine builds for more
  settings =
    (import <| self + /flake.nix).nixConfig
    // optionalAttrs (extra-platforms != [ ]) { inherit extra-platforms; };
  includeGithubToken = "!include ${config.secrets.github-token-nix-conf.path}";

  determinateNix = inputs.determinate.inputs.nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
  determinateNixRuntime = pkgs.symlinkJoin {
    pname = "determinate-nix";
    version = determinateNix.version;
    name = "determinate-nix-${determinateNix.version}";
    paths = [ (lib.getOutput "out" determinateNix) ];
  };
in
mkMerge [
  {
    secrets.github-token-nix-conf = {
      file = ./github-token-nix-conf.age;
      mode = "444";
      owner = "root";
    };

    environment.variables.NIX_PATH = mkForce (
      flakes
      |> mapAttrsToList (name: value: "${name}=${value}")
      |> (if isDarwin then concatStringsSep ":" else id)
    );
  }

  (
    if isDarwin then
      {
        determinateNix = {
          inherit registry;
          customSettings = removeAttrs settings [ "use-cgroups" ] // {
            # Determinate points the global registry at the system one whenever
            # it writes a registry; empty keeps it off, as on NixOS
            flake-registry = mkForce settings.flake-registry;
          };
        };

        environment.etc."nix/nix.custom.conf".text = mkAfter includeGithubToken;

        # The daemon reads its settings only when it starts, and Determinate never
        # restarts it on a switch: a changed setting, a post-build hook among them,
        # waits for a reboot, and a hook named by an old store path fails every local
        # build once a garbage collection deletes it. The stamp holds the settings the
        # daemon was last started with, so a switch restarts it when they changed, and
        # the first switch with this restarts it once. The restart waits until the
        # daemon answers, since later activation steps may use it.
        system.activationScripts.postActivation.text = mkAfter ''
          stamp=/var/db/nix-daemon-settings.sha256
          settings=$(
            { /bin/cat /etc/nix/nix.conf /etc/nix/nix.custom.conf /etc/determinate/config.json 2>/dev/null || true; } |
              /usr/bin/shasum -a 256 | /usr/bin/cut -d ' ' -f 1
          )
          if [ "$(/bin/cat "$stamp" 2>/dev/null)" != "$settings" ]; then
            echo "restarting the Nix daemon for its changed settings..." >&2
            if /bin/launchctl kickstart -k system/systems.determinate.nix-daemon; then
              for _ in $(/usr/bin/seq 1 50); do
                /nix/var/nix/profiles/default/bin/nix store info --store daemon >/dev/null 2>&1 && break
                /bin/sleep 0.2
              done
              echo "$settings" > "$stamp"
            else
              echo "warning: restarting the Nix daemon failed; it keeps its old settings" >&2
            fi
          fi
        '';
      }
    else
      {
        nix = {
          inherit registry settings;
          extraOptions = includeGithubToken;
          # Determinate's cache publishes the runtime output, not Nix's auxiliary outputs.
          package = mkForce determinateNixRuntime;
        };
      }
  )
]
