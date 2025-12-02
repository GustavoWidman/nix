{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.lists)
    optionals
    ;
in
{
  environment.systemPackages =
    with pkgs;
    [
      nh
      nix-index
      nix-output-monitor
    ]
    ++ optionals config.isDev [
      nixfmt-rfc-style
      deploy-rs
      nixd
    ];
}
