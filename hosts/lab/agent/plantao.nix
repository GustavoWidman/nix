{ lib, pkgs, ... }:

{
  # These manually managed units pinned an old /nix/store Node executable.
  # Override only the runtime, retaining their environment, data and startup
  # policy. No WantedBy: this must not re-enable the demo at boot.
  systemd.user.services = lib.genAttrs [ "plantao-app" "plantao-app-dev" ] (_: {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = [
      ""
      "${pkgs.nodejs_26}/bin/node %h/.local/lib/plantao-app/server/index.mjs"
    ];
  });
}
