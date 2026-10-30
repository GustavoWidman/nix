{
  config,
  lib,
  niks3,
  isDarwin,
  pkgs,
  ...
}:
let
  cfg = config.services.niks3-auto-upload;
  nix = if isDarwin then "/nix/var/nix/profiles/default/bin/nix" else "${config.nix.package}/bin/nix";
  hookPackage = cfg.package.override { postBuildHookSocketPath = cfg.socketPath; };
  filteredHook = pkgs.writeShellScript "niks3-filtered-post-build-hook" ''
    set -uf
    export IFS=' '

    # Downloads and fixed-output source fetches are not expensive local builds.
    if [ -z "''${DRV_PATH:-}" ] || [ -z "''${OUT_PATHS:-}" ]; then
      exit 0
    fi
    if ! drv=$(${nix} derivation show "$DRV_PATH" 2>/dev/null); then
      echo "niks3: skipping upload; cannot inspect derivation" >&2
      exit 0
    fi
    if ! printf '%s' "$drv" | ${pkgs.jq}/bin/jq -e '
      all(.[]; all(.outputs[]; (has("hash") or has("hashAlgo")) | not)
        and ((.env.outputHash // "") == ""))
    ' >/dev/null; then
      exit 0
    fi

    selected=""
    for output in $OUT_PATHS; do
      # Measure this output, not its dependencies: a tiny system wrapper can
      # reference the entire machine and must never qualify by closure size.
      if ! info=$(${nix} path-info --json "$output" 2>/dev/null); then
        continue
      fi
      if ! printf '%s' "$info" | ${pkgs.jq}/bin/jq -e \
        'all(.[]; .narSize >= ${toString cfg.minNarSize})' >/dev/null; then
        continue
      fi
      if ! closure=$(${nix} path-info --recursive --json "$output" 2>/dev/null); then
        continue
      fi
      if ! printf '%s' "$closure" | ${pkgs.jq}/bin/jq -e \
        '([.[] | .narSize] | add) <= ${toString cfg.maxClosureNarSize}' >/dev/null; then
        echo "niks3: skipping $output; runtime closure exceeds upload limit" >&2
        continue
      fi
      selected="$selected $output"
    done

    if [ -n "$selected" ]; then
      export OUT_PATHS="$selected"
      exec ${lib.getExe' hookPackage "niks3-hook"} send "$@"
    fi
  '';
in
{
  # specialArgs are available while collecting imports; config is not.
  imports = [
    (if isDarwin then niks3.darwinModules.niks3-auto-upload else niks3.nixosModules.niks3-auto-upload)
  ];

  options.services.niks3-auto-upload = {
    minNarSize = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 10 * 1024 * 1024;
      description = "Minimum size in bytes of a locally built output eligible for automatic upload.";
    };
    maxClosureNarSize = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 512 * 1024 * 1024;
      description = "Maximum total uncompressed runtime closure size for one automatic upload.";
    };
  };

  config = lib.mkMerge [
    {
      secrets.cache-token.file = ./token.age;

      services.niks3-auto-upload = {
        enable = true;
        # The cache is backed by a single USB HDD; avoid parallel write storms.
        maxConcurrentUploads = 2;
        serverUrl = "https://cache.r3dlust.com";
        authTokenFile = config.secrets.cache-token.path;
      };

      nix.settings.post-build-hook = lib.mkForce (toString filteredHook);
    }
    (lib.optionalAttrs isDarwin {
      # Determinate manages Nix, so nix-darwin's nix.package is unavailable.
      launchd.daemons.niks3-auto-upload.serviceConfig.EnvironmentVariables = lib.mkForce {
        PATH = "/nix/var/nix/profiles/default/bin:/usr/bin:/bin";
      };

      # nix.enable is false on Darwin; use the shim consumed by Determinate.
      nix-settings.post-build-hook = config.nix.settings.post-build-hook;
    })
  ];
}
