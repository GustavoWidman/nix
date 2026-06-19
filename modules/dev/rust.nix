{
  config,
  fenix,
  pkgs,
  ...
}:

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

  home-manager.sharedModules = [
    (
      { config, ... }:
      {
        home.sessionVariables = {
          RUSTC_WRAPPER = "sccache";
          CARGO_INCREMENTAL = "0";
          SCCACHE_CACHE_SIZE = "20G";
          SCCACHE_DIR = "${config.home.homeDirectory}/.cache/sccache";
        };

        home.file.".cargo/config.toml" = {
          text = ''
            [net]
            git-fetch-with-cli = true

            [build]
            rustc-wrapper="sccache"
            incremental = false
          '';
          # sccache doesn't support incremental compilation,
          # so disable it to avoid sccache never working at all
          force = true;
        };
      }
    )
  ];
}
