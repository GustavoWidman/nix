{
  config,
  fenix,
  lib,
  pkgs,
  ...
}:

let
  kacheExe = "${config.services.kache.package}/bin/kache";
  cargoTargetDir = "/mnt/encrypted/oracle/cargo-target";
in
{
  services.kache = {
    enable = true;
    daemon.enable = true;
    rustcWrapper = true;
    settings.cache = {
      local_max_size = "20G";
      clean_incremental = true;
      daemon_idle_timeout_secs = 600;
    };
  };

  environment.systemPackages = [
    (fenix.packages.${config.metadata.architecture}.complete.withComponents [
      "cargo"
      "clippy"
      "rustc"
      "rustfmt"
      "rust-analyzer"
      "rust-src"
    ])
    pkgs.cargo-sweep
    pkgs.cargo-info
    pkgs.sqlx-cli
  ];

  environment.variables = {
    RUSTC_WRAPPER = kacheExe;
    CARGO_INCREMENTAL = "0";
    CC = "${kacheExe} cc";
    CXX = "${kacheExe} c++";
  };

  home-manager.sharedModules = [
    (
      { config, osConfig, ... }:
      {
        home.sessionVariables = {
          RUSTC_WRAPPER = kacheExe;
          CARGO_INCREMENTAL = "0";
          CC = "${kacheExe} cc";
          CXX = "${kacheExe} c++";
        };

        home.file.".cargo/config.toml" = {
          text = ''
            [net]
            git-fetch-with-cli = true

            [build]
            rustc-wrapper="${kacheExe}"
            incremental = false
            ${lib.optionalString (osConfig.metadata.hostname == "lab") ''
              target-dir = "${cargoTargetDir}/${config.home.username}"
            ''}
          '';
          force = true;
        };
      }
    )
  ];
}
