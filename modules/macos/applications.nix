{ lib, pkgs, ... }:
let
  linkAppsScript = pkgs.writeShellScript "link-apps" ''
    set -euo pipefail

    source_dir=$1
    target_dir=$2
    mkdir -p "$target_dir"

    # Only remove stale links that point to the matching app in our source folder.
    for link in "$target_dir"/*.app; do
      [ -L "$link" ] || continue
      expected_target="$source_dir/''${link##*/}"
      if [ "$(readlink "$link")" = "$expected_target" ] && [ ! -e "$expected_target" ]; then
        rm "$link"
      fi
    done

    for app in "$source_dir"/*.app; do
      [ -e "$app" ] || continue
      link="$target_dir/''${app##*/}"
      if [ -L "$link" ] && [ "$(readlink "$link")" = "$app" ]; then
        continue
      fi
      if [ -e "$link" ] || [ -L "$link" ]; then
        printf 'Skipping app link: %s already exists\n' "$link" >&2
        continue
      fi
      ln -s "$app" "$link"
    done
  '';
in
{
  system.activationScripts.applications.text = lib.mkAfter ''
    /bin/bash ${linkAppsScript} '/Applications/Nix Apps' /Applications
  '';

  home-manager.sharedModules = [
    (
      { config, lib, ... }:
      let
        linkApps = config.targets.darwin.linkApps;
        copyApps = config.targets.darwin.copyApps;
        directory = if copyApps.enable then copyApps.directory else linkApps.directory;
        home = config.home.homeDirectory;
      in
      {
        home.activation.linkAppsToApplications = lib.mkIf (linkApps.enable || copyApps.enable) (
          lib.hm.dag.entryAfter ([ "linkGeneration" ] ++ lib.optional copyApps.enable "copyApps") ''
            run /bin/bash ${linkAppsScript} \
              ${lib.escapeShellArg "${home}/${directory}"} \
              ${lib.escapeShellArg "${home}/Applications"}
          ''
        );
      }
    )
  ];
}
